import json
import asyncio
import re
from pathlib import Path
import spacy
from spacy.matcher import PhraseMatcher


class SpacySkillsExtractor:

    def __init__(self):
        # On ne garde que le tokenizer, tout le reste (tagger, parser, NER...) est inutile pour le PhraseMatcher
        self.nlp_en = spacy.load("en_core_web_sm", disable=["tok2vec", "tagger", "parser", "attribute_ruler", "lemmatizer", "ner"])
        self.nlp_fr = spacy.load("fr_core_news_sm", disable=["tok2vec", "morphologizer", "parser", "attribute_ruler", "lemmatizer", "ner"])
        self.skills_by_category, self.skills_list, self.skill_to_canonical = self._load_skills_reference()
        self.sensitive_skills = self._load_sensitive_skills()
        self.matcher_en = self._build_matcher(self.nlp_en)
        self.matcher_fr = self._build_matcher(self.nlp_fr)
        self._compile_sensitive_patterns()
    
    # Charge sensitive_skills.json
    def _load_sensitive_skills(self) -> dict:
        sensitive_path = Path(__file__).parent.parent.parent / "models" / "data" / "sensitive_skills.json"
        with open(sensitive_path, "r", encoding="utf-8") as f:
            return json.load(f)
    
    # Compile les patterns regex pour les skills sensibles (un seul regex par skill)
    def _compile_sensitive_patterns(self):
        self.sensitive_compiled = {}
        for skill, config in self.sensitive_skills.items():
            combined = "|".join(config["safe_patterns"])
            self.sensitive_compiled[skill] = re.compile(combined, re.IGNORECASE)

    # Charge skills.json et construit les mappings de variantes
    def _load_skills_reference(self) -> tuple[dict, list, dict]:
        skills_path = Path(__file__).parent.parent.parent / "models" / "data" / "skills.json"
        with open(skills_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        by_category = {}
        flat_list = []
        skill_to_canonical = {}

        for category, skills in data.get("IT", {}).items():
            by_category[category] = []
            for skill_data in skills:
                name = skill_data["name"]
                variants = skill_data.get("variants", [])

                by_category[category].append(name)
                flat_list.append(name)

                skill_to_canonical[name.lower()] = name

                for variant in variants:
                    if variant:
                        skill_to_canonical[variant.lower()] = name

        return by_category, flat_list, skill_to_canonical

    # Construit le PhraseMatcher avec tous les patterns de skills et variantes
    def _build_matcher(self, nlp) -> PhraseMatcher:
        matcher = PhraseMatcher(nlp.vocab, attr="LOWER")

        patterns = []
        for term in self.skill_to_canonical.keys():
            doc = nlp.make_doc(term)
            patterns.append(doc)

        if patterns:
            matcher.add("SKILLS", patterns)

        return matcher

    # Trouve la catégorie d'un skill
    def _get_category(self, skill_name: str) -> str:
        for category, skills in self.skills_by_category.items():
            if skill_name in skills:
                return category
        return "other"

    def _is_valid_sensitive_skill(self, skill: str, text: str, match_start: int, match_end: int) -> bool:
        config = self.sensitive_skills.get(skill)
        if not config:
            return True  # Pas un skill sensible, toujours valide

        text_lower = text.lower()

        # 1. Vérifier les patterns sûrs (ex: "golang" → Go, "apache spark" → Spark)
        if self.sensitive_compiled[skill].search(text_lower):
            return True

        # 2. Vérifier si isolé et en majuscule (pour C, R, Go, D)
        if config.get("require_isolated_uppercase"):
            matched_text = text[match_start:match_end]

            # Le match doit être exactement le skill (en majuscule)
            if matched_text != skill:
                return False

            # Vérifier l'isolation (espaces ou ponctuation autour)
            char_before = text[match_start - 1] if match_start > 0 else " "
            char_after = text[match_end] if match_end < len(text) else " "

            is_isolated = (
                not char_before.isalnum() and
                not char_after.isalnum()
            )

            return is_isolated

      
        return False

    # Extraction des skills
    def _extract_skills_sync(self, job_description: str) -> list[str]:
        if not job_description:
            return []

        text = job_description[:5000]
        found_skills = set()

        # Extraction avec le modèle anglais (make_doc = tokenisation seule, pas d'analyse grammaticale)
        doc_en = self.nlp_en.make_doc(text)
        matches_en = self.matcher_en(doc_en)
        for match_id, start, end in matches_en:
            span_text = doc_en[start:end].text.lower()
            canonical = self.skill_to_canonical.get(span_text)
            if canonical:
                # Validation des skills sensibles
                char_start = doc_en[start].idx
                char_end = doc_en[end - 1].idx + len(doc_en[end - 1].text)
                if self._is_valid_sensitive_skill(canonical, text, char_start, char_end):
                    found_skills.add(canonical)

        # Extraction avec le modèle français
        doc_fr = self.nlp_fr.make_doc(text)
        matches_fr = self.matcher_fr(doc_fr)
        for match_id, start, end in matches_fr:
            span_text = doc_fr[start:end].text.lower()
            canonical = self.skill_to_canonical.get(span_text)
            if canonical:
                char_start = doc_fr[start].idx
                char_end = doc_fr[end - 1].idx + len(doc_fr[end - 1].text)
                if self._is_valid_sensitive_skill(canonical, text, char_start, char_end):
                    found_skills.add(canonical)

        return list(found_skills)

    # Extrait les skills d'une description d'un poste
    async def extract_skills(self, job_description: str) -> list[str]:
        return await asyncio.to_thread(self._extract_skills_sync, job_description)

    # Retourne une liste de skills avec leur catégorie
    async def extract_skills_list(self, job_description: str) -> list[dict]:
        skills = await self.extract_skills(job_description)
        return [
            {"name": skill, "category": self._get_category(skill)}
            for skill in skills
        ]

    # Extrait les skills de plusieurs descriptions en parallèle
    async def extract_all_skills(self, descriptions: list[str], max_concurrent: int = 5) -> list[list[dict]]:
        semaphore = asyncio.Semaphore(max_concurrent)

        async def extract_with_limit(desc: str) -> list[dict]:
            async with semaphore:
                return await self.extract_skills_list(desc)

        tasks = [extract_with_limit(desc) for desc in descriptions]
        results = await asyncio.gather(*tasks, return_exceptions=True)

        return [r for r in results if isinstance(r, list)]

    # Extrait les skills de N descriptions et les classe par fréquence d'apparition
    async def extract_and_rank(self, descriptions: list[str]) -> list[dict]:
        from collections import Counter

        total = len(descriptions)
        if total == 0:
            return []

        # Compte chaque skill une fois par description (set pour dédupliquer par offre)
        skill_counter: Counter[str] = Counter()
        for desc in descriptions:
            skills = await self.extract_skills(desc)
            skill_counter.update(set(skills))

        # Retourne les skills triés par fréquence décroissante
        ranked = [
            {
                "name": name,
                "category": self._get_category(name),
                "count": count,
                "percentage": round((count / total) * 100),
            }
            for name, count in skill_counter.most_common()
        ]
        return ranked


spacy_extractor = SpacySkillsExtractor()