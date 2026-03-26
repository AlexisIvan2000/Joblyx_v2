"""add_ghosted_status_to_applications

Revision ID: 3420247fda06
Revises: f3782e62c0d8
Create Date: 2026-03-26 01:32:08.044666

"""
from typing import Sequence, Union

from alembic import op


# revision identifiers, used by Alembic.
revision: str = '3420247fda06'
down_revision: Union[str, Sequence[str], None] = 'f3782e62c0d8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Ajouter 'ghosted' aux statuts valides des candidatures."""
    op.drop_constraint('applications_status_check', 'applications', type_='check')
    op.create_check_constraint(
        'applications_status_check',
        'applications',
        "status IN ('saved','applied','online_assessment','phone_screen','technical','final_interview','offer','accepted','rejected','ghosted','withdrawn')",
    )


def downgrade() -> None:
    """Retirer 'ghosted' des statuts valides."""
    op.drop_constraint('applications_status_check', 'applications', type_='check')
    op.create_check_constraint(
        'applications_status_check',
        'applications',
        "status IN ('saved','applied','online_assessment','phone_screen','technical','final_interview','offer','accepted','rejected','withdrawn')",
    )
