from core.exceptions import InvalidFileType, FileTooLarge

PDF_MAX_BYTES = 5 * 1024 * 1024
PDF_MAX_BYTES_LARGE = 10 * 1024 * 1024
AVATAR_MAX_BYTES = 10 * 1024 * 1024
ALLOWED_IMAGE_TYPES = ("image/jpeg", "image/png")


def _mb(num_bytes: int) -> int:
    return num_bytes // (1024 * 1024)


def validate_pdf(content_type: str | None, size: int, *, max_bytes: int = PDF_MAX_BYTES) -> None:
    if not content_type or "pdf" not in content_type:
        raise InvalidFileType("Only PDF files are accepted")
    if size > max_bytes:
        raise FileTooLarge(f"File too large (max {_mb(max_bytes)} MB)")


def validate_image(content_type: str | None, size: int, *, max_bytes: int = AVATAR_MAX_BYTES) -> None:
    if not content_type or content_type not in ALLOWED_IMAGE_TYPES:
        raise InvalidFileType("Only JPEG, PNG images are accepted")
    if size > max_bytes:
        raise FileTooLarge(f"File too large (max {_mb(max_bytes)} MB)")
