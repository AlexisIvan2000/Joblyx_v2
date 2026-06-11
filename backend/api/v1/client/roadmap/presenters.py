def phase_to_dict(phase) -> dict:
    return {
        "id": str(phase.id),
        "phase_number": phase.phase_number,
        "title": phase.title,
        "duration_weeks": phase.duration_weeks,
        "objective": phase.objective,
        "skills": phase.skills or [],
        "actions": phase.actions or [],
        "resources": phase.resources or [],
        "certifications": phase.certifications or [],
        "projects": phase.projects or [],
        "milestone": phase.milestone,
        "completed": phase.completed,
        "custom": phase.custom,
        "user_notes": phase.user_notes,
        "position": phase.position,
    }


def roadmap_to_response(roadmap) -> dict:
    return {
        "id": str(roadmap.id),
        "summary": roadmap.summary,
        "phases": [phase_to_dict(p) for p in sorted(roadmap.phases, key=lambda p: p.position)],
        "status": roadmap.status,
        "created_at": roadmap.created_at.isoformat() if roadmap.created_at else None,
    }
