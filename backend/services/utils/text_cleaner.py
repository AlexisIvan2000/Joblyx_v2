import re

_MAX_CV_LENGTH = 8000


def clean_cv_text(raw_text: str) -> str:
    
    if not raw_text:
        return ""

    text = raw_text

    # Retirer les lignes de décoration (tirets, underscores, astérisques, etc.)
    text = re.sub(r"^[\s\-_=*•·│|─━►▪▸→←↓↑]+$", "", text, flags=re.MULTILINE)

    # Retirer les numéros de page isolés
    text = re.sub(r"^\s*(?:Page\s*)?\d{1,3}\s*(?:of\s*\d{1,3})?\s*$", "", text, flags=re.MULTILINE | re.IGNORECASE)

    # Strip chaque ligne
    lines = [line.strip() for line in text.split("\n")]

    # Retirer les headers/footers répétés (lignes identiques qui apparaissent 3+ fois)
    line_counts: dict[str, int] = {}
    for line in lines:
        if line:
            line_counts[line] = line_counts.get(line, 0) + 1
    repeated = {line for line, count in line_counts.items() if count >= 3}
    lines = [line for line in lines if line not in repeated]

    text = "\n".join(lines)

    # Espaces multiples → un seul
    text = re.sub(r"[ \t]{2,}", " ", text)

    # Lignes vides multiples → une seule
    text = re.sub(r"\n{3,}", "\n\n", text)

    text = text.strip()

    # Tronquer au dernier espace
    if len(text) > _MAX_CV_LENGTH:
        text = text[:_MAX_CV_LENGTH].rsplit(" ", 1)[0]

    return text
