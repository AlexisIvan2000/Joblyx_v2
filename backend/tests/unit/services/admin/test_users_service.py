import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from core.exceptions import (
    CannotModifyFounder,
    CannotModifySuperAdmin,
    CannotPromoteToSuperAdmin,
)
from services.admin import users_service as users_service_module
from services.admin.users_service import AdminUsersService
from tests.conftest import _make_user_obj


FOUNDER_EMAIL = "founder@joblyx.com"


@pytest.fixture
def admin_users_service(monkeypatch):
    
    # On force ADMIN_EMAIL pour que _is_founder soit déterministe en test
    monkeypatch.setattr(users_service_module, "ADMIN_EMAIL", FOUNDER_EMAIL)

    session = AsyncMock()
    svc = AdminUsersService(session)

    # Remplace les repos par des AsyncMock pour contrôler le comportement
    svc.admin_repo = AsyncMock()
    svc.audit_repo = AsyncMock()
    svc.auth_repo = AsyncMock()
    svc.rt_repo = AsyncMock()
    return svc


# 1. _check_can_modify bloque les actions sur le founder

class TestFounderProtection:
    @pytest.mark.asyncio
    async def test_set_user_status_raises_on_founder(self, admin_users_service):
        founder = _make_user_obj(email=FOUNDER_EMAIL, role="super_admin")
        admin_users_service.admin_repo.get_user.return_value = founder

        # Même appelé par un super_admin, le founder reste verrouillé
        with pytest.raises(CannotModifyFounder):
            await admin_users_service.set_user_status(
                str(founder.id), is_active=False, reason="test",
                admin_id="some-admin-id", caller_role="super_admin",
            )

        # Aucun write ne doit s'être déclenché
        admin_users_service.admin_repo.set_user_status.assert_not_called()
        admin_users_service.audit_repo.create.assert_not_called()


# 2. _check_can_modify bloque toute action sur un super_admin, quel que soit l'appelant

class TestSuperAdminProtection:
    @pytest.mark.asyncio
    async def test_set_user_status_raises_when_admin_targets_super_admin(self, admin_users_service):
        target = _make_user_obj(
            id=uuid.UUID("22222222-2222-2222-2222-222222222222"),
            email="another-super@joblyx.com",
            role="super_admin",
        )
        admin_users_service.admin_repo.get_user.return_value = target

        # Un admin classique ne peut pas toucher un super_admin
        with pytest.raises(CannotModifySuperAdmin):
            await admin_users_service.set_user_status(
                str(target.id), is_active=False, reason=None,
                admin_id="admin-id", caller_role="admin",
            )

        admin_users_service.admin_repo.set_user_status.assert_not_called()

    @pytest.mark.asyncio
    async def test_super_admin_cannot_modify_other_super_admin(self, admin_users_service):
        """Policy : un super_admin est immuable via l'API, même appelé par un autre super_admin.
        La récupération d'un compte super_admin compromis passe uniquement par SQL direct."""
        target = _make_user_obj(
            id=uuid.UUID("33333333-3333-3333-3333-333333333333"),
            email="another-super@joblyx.com",
            role="super_admin",
        )
        admin_users_service.admin_repo.get_user.return_value = target

        with pytest.raises(CannotModifySuperAdmin):
            await admin_users_service.set_user_status(
                str(target.id), is_active=False, reason=None,
                admin_id="super-id", caller_role="super_admin",
            )
        admin_users_service.admin_repo.set_user_status.assert_not_called()
        admin_users_service.audit_repo.create.assert_not_called()


# 3. update_user_role refuse la promotion vers super_admin

class TestRolePromotionGuard:
    @pytest.mark.asyncio
    async def test_promotion_to_super_admin_is_rejected(self, admin_users_service):
        target = _make_user_obj(email="someone@joblyx.com", role="user")
        admin_users_service.admin_repo.get_user.return_value = target

        with pytest.raises(CannotPromoteToSuperAdmin):
            await admin_users_service.update_user_role(
                str(target.id), new_role="super_admin",
                admin_id="super-id",
            )

        admin_users_service.admin_repo.update_user_role.assert_not_called()
        admin_users_service.audit_repo.create.assert_not_called()


# 4. update_user_role : un super_admin se ciblant lui-même est bloqué par l'immuabilité
#    (le check self devient inatteignable car l'appelant est toujours super_admin)

class TestSelfModificationGuard:
    @pytest.mark.asyncio
    async def test_cannot_change_own_role(self, admin_users_service):
        admin = _make_user_obj(
            id=uuid.UUID("44444444-4444-4444-4444-444444444444"),
            email="me@joblyx.com",
            role="super_admin",
        )
        admin_users_service.admin_repo.get_user.return_value = admin

        with pytest.raises(CannotModifySuperAdmin):
            await admin_users_service.update_user_role(
                str(admin.id), new_role="admin",
                admin_id=str(admin.id),
            )

        admin_users_service.admin_repo.update_user_role.assert_not_called()


# 6. update_user_role verrouille le rôle super_admin et coupe les sessions en cas de rétrogradation

class TestRoleChangeProtection:
    @pytest.mark.asyncio
    async def test_cannot_change_super_admin_role(self, admin_users_service):
        target = _make_user_obj(
            id=uuid.UUID("55555555-5555-5555-5555-555555555555"),
            email="super@joblyx.com",
            role="super_admin",
        )
        admin_users_service.admin_repo.get_user.return_value = target

        with pytest.raises(CannotModifySuperAdmin):
            await admin_users_service.update_user_role(
                str(target.id), new_role="admin", admin_id="other-super-id",
            )
        admin_users_service.admin_repo.update_user_role.assert_not_called()

    @pytest.mark.asyncio
    async def test_demotion_admin_to_user_revokes_refresh_tokens(self, admin_users_service):
        target = _make_user_obj(
            id=uuid.UUID("66666666-6666-6666-6666-666666666666"),
            email="admin@joblyx.com",
            role="admin",
        )
        admin_users_service.admin_repo.get_user.return_value = target
        admin_users_service.admin_repo.update_user_role.return_value = target

        await admin_users_service.update_user_role(
            str(target.id), new_role="user", admin_id="super-id",
        )
        # Perte de privilèges : toutes les sessions sont révoquées
        admin_users_service.rt_repo.revoke_all_for_user.assert_called_once_with(str(target.id))

    @pytest.mark.asyncio
    async def test_promotion_user_to_admin_does_not_revoke(self, admin_users_service):
        target = _make_user_obj(
            id=uuid.UUID("77777777-7777-7777-7777-777777777777"),
            email="user@joblyx.com",
            role="user",
        )
        admin_users_service.admin_repo.get_user.return_value = target
        admin_users_service.admin_repo.update_user_role.return_value = target

        await admin_users_service.update_user_role(
            str(target.id), new_role="admin", admin_id="super-id",
        )
        # Promotion : aucune révocation
        admin_users_service.rt_repo.revoke_all_for_user.assert_not_called()


# 5. delete_user empêche la suppression du founder

class TestDeleteFounderProtection:
    @pytest.mark.asyncio
    async def test_cannot_delete_founder(self, admin_users_service):
        founder = _make_user_obj(email=FOUNDER_EMAIL, role="super_admin")
        admin_users_service.admin_repo.get_user.return_value = founder

        with pytest.raises(CannotModifyFounder):
            await admin_users_service.delete_user(
                str(founder.id),
                admin_id="super-id", caller_role="super_admin",
            )

        # Le delete ne doit jamais avoir été exécuté côté repo
        admin_users_service.auth_repo.delete_user.assert_not_called()
        # L'audit ne doit pas non plus avoir été écrit (le guard pète AVANT)
        admin_users_service.audit_repo.create.assert_not_called()
