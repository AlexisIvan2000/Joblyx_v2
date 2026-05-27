from decimal import Decimal

# Tarifs en USD pour 1 000 000 tokens
_PRICING_PER_MILLION: dict[str, dict[str, Decimal]] = {
    "gpt-4o":      {"input": Decimal("2.50"), "output": Decimal("10.00")},
    "gpt-4o-mini": {"input": Decimal("0.15"), "output": Decimal("0.60")},
    "gpt-4-turbo": {"input": Decimal("10.00"), "output": Decimal("30.00")},
    "gpt-3.5-turbo": {"input": Decimal("0.50"), "output": Decimal("1.50")},
}

# Fallback quand un modèle inconnu est utilisé, on facture au tarif gpt-4o pour ne pas sous-estimer
_FALLBACK = _PRICING_PER_MILLION["gpt-4o"]

# Calcule le coût d'un appel OpenAI en USD à partir des compteurs de tokens.
def calculate_cost(model: str, prompt_tokens: int, completion_tokens: int) -> Decimal:
    rates = _PRICING_PER_MILLION.get(model, _FALLBACK)
    cost_input = (Decimal(prompt_tokens) * rates["input"]) / Decimal(1_000_000)
    cost_output = (Decimal(completion_tokens) * rates["output"]) / Decimal(1_000_000)
    # Arrondi à 4 décimales pour matcher la précision en base
    return (cost_input + cost_output).quantize(Decimal("0.0001"))
