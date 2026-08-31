"""Lógica local para clasificar descripciones de servicios Cloud."""

from dataclasses import dataclass
import re
import unicodedata


@dataclass(frozen=True)
class ClassificationResult:
    """Resultado sencillo que la GUI puede mostrar sin conocer las reglas."""

    model: str
    score: int
    matched_concepts: tuple[str, ...]


@dataclass(frozen=True)
class ProcessedText:
    """Representa las etapas sencillas del procesamiento NLP."""

    clean_text: str
    tokens: tuple[str, ...]
    relevant_tokens: tuple[str, ...]
    stems: frozenset[str]


# Palabras frecuentes que no ayudan a distinguir un modelo Cloud.
SPANISH_STOPWORDS = {
    "a", "al", "cada", "como", "con", "de", "del", "desde", "el", "ella",
    "en", "es", "esta", "este", "la", "las", "lo", "los", "mi", "para",
    "por", "que", "quiero", "se", "sin", "su", "sus", "un", "una", "unos",
    "unas", "usuario", "utiliza", "utilizan", "vez", "y",
}


# Cada regla contiene una expresión, sus puntos y un nombre comprensible.
RULES = {
    "IaaS": (
        (r"\bmaquinas?\s+virtual(?:es)?\b|\bvirtual\s+machines?\b", 5, "máquinas virtuales"),
        (r"\bred(?:es)?\s+configurables?\b", 4, "redes configurables"),
        (r"\b(?:infraestructura|infrastructure)\b", 4, "infraestructura"),
        (r"\b(?:almacenamiento|storage)\b", 2, "almacenamiento"),
        (r"\b(?:servidores?|servers?)\b", 1, "servidores"),
    ),
    "PaaS": (
        (r"\b(?:desplegar|deploy)\b.{0,35}\b(?:aplicacion|application|app)\b", 5, "desplegar aplicación"),
        (r"\b(?:aplicacion\s+web|web\s+app(?:lication)?)\b", 4, "aplicación web"),
        (r"\b(?:plataforma|platform|runtime|app\s+service)\b", 4, "plataforma"),
        (r"\bsin\s+administrar\b.{0,40}\bservidores?\b", 6, "sin administrar servidores"),
        (r"\b(?:desarrollo|development)\b", 3, "desarrollo"),
    ),
    "SaaS": (
        (r"\b(?:correo\s+electronico|email)\b", 4, "correo electrónico"),
        (r"\b(?:navegador|browser)\b", 4, "navegador"),
        (r"\b(?:suscripcion|subscription)\b", 4, "suscripción"),
        (r"\bsoftware\s+(?:listo\s+para\s+usar|ready\s+to\s+use)\b", 5, "software listo para usar"),
        (r"\b(?:usuario\s+final|end\s+user)\b", 3, "usuario final"),
    ),
    "FaaS": (
        (r"\b(?:ejecutar|execute|run)\b.{0,25}\b(?:una\s+)?funcion\b", 5, "ejecutar una función"),
        (r"\bfuncion\s+(?:serverless|activada\s+por\s+(?:un\s+)?evento)\b", 6, "función por evento"),
        (r"\b(?:serverless|lambda)\b", 5, "serverless"),
        (r"\b(?:automaticamente|automatically)\b", 2, "automáticamente"),
        (r"\b(?:evento|event|trigger)\b", 3, "evento"),
    ),
}


# Los stems complementan las frases Regex y permiten reconocer variaciones
# sencillas como "servidores" y "servidor" sin duplicar reglas completas.
CONCEPT_STEMS = {
    "IaaS": {
        "maquina": (2, "máquina"),
        "virtual": (2, "virtual"),
        "almacenamiento": (2, "almacenamiento"),
        "red": (2, "red"),
        "infraestructura": (4, "infraestructura"),
        "servidor": (1, "servidor"),
    },
    "PaaS": {
        "despleg": (4, "desplegar"),
        "plataforma": (4, "plataforma"),
        "desarrollo": (3, "desarrollo"),
        "runtime": (3, "runtime"),
    },
    "SaaS": {
        "correo": (3, "correo"),
        "electronico": (2, "electrónico"),
        "navegador": (3, "navegador"),
        "suscripcion": (4, "suscripción"),
    },
    "FaaS": {
        "funcion": (4, "función"),
        "automatica": (2, "automáticamente"),
        "evento": (3, "evento"),
        "serverless": (5, "serverless"),
        "lambda": (5, "lambda"),
    },
}


def normalize_text(text: str) -> str:
    """Convierte a minúsculas y elimina acentos para comparar variantes."""

    lowered = text.lower().strip()
    decomposed = unicodedata.normalize("NFD", lowered)
    return "".join(char for char in decomposed if unicodedata.category(char) != "Mn")


def stem_token(token: str) -> str:
    """Aplica un stemming pequeño basado en terminaciones frecuentes.

    No es un lematizador completo: solo agrupa algunas variantes útiles para
    este ejercicio y evita la necesidad de instalar librerías externas.
    """

    if len(token) > 7 and token.endswith("mente"):
        return token[:-5]
    if len(token) > 6 and token.endswith("ciones"):
        return token[:-5] + "cion"
    if len(token) > 5 and token.endswith(("ar", "er", "ir")):
        return token[:-2]
    if len(token) > 4 and token.endswith("es"):
        return token[:-2]
    if len(token) > 3 and token.endswith("s"):
        return token[:-1]
    return token


def preprocess_text(text: str) -> ProcessedText:
    """Ejecuta limpieza, tokenización, stopwords y stemming básico."""

    # 1. Minúsculas y eliminación de acentos.
    normalized = normalize_text(text)

    # 2. Limpieza: conserva letras y números, y unifica los espacios.
    clean_text = re.sub(r"[^a-z0-9]+", " ", normalized)
    clean_text = re.sub(r"\s+", " ", clean_text).strip()

    # 3. Tokenización: cada palabra pasa a ser un elemento independiente.
    tokens = tuple(clean_text.split()) if clean_text else ()

    # 4. Stopwords: se conservan solo términos con mayor valor descriptivo.
    relevant_tokens = tuple(
        token for token in tokens if token not in SPANISH_STOPWORDS
    )

    # 5. Stemming: reduce plurales y algunas terminaciones verbales.
    stems = frozenset(stem_token(token) for token in relevant_tokens)
    return ProcessedText(clean_text, tokens, relevant_tokens, stems)


def score_category(text: str, category: str) -> tuple[int, tuple[str, ...]]:
    """Calcula la puntuación de una categoría sin mezclar sus reglas."""

    score = 0
    matches = []
    for pattern, points, concept in RULES[category]:
        if re.search(pattern, text, flags=re.IGNORECASE):
            score += points
            matches.append(concept)
    return score, tuple(matches)


def score_concepts(stems: frozenset[str], category: str) -> tuple[int, tuple[str, ...]]:
    """Asigna puntos adicionales a conceptos encontrados tras el stemming."""

    score = 0
    matches = []
    for stem, (points, concept) in CONCEPT_STEMS[category].items():
        if stem in stems:
            score += points
            matches.append(concept)
    return score, tuple(matches)


def identify_iaas(text: str) -> tuple[int, tuple[str, ...]]:
    return score_category(text, "IaaS")


def identify_paas(text: str) -> tuple[int, tuple[str, ...]]:
    return score_category(text, "PaaS")


def identify_saas(text: str) -> tuple[int, tuple[str, ...]]:
    return score_category(text, "SaaS")


def identify_faas(text: str) -> tuple[int, tuple[str, ...]]:
    return score_category(text, "FaaS")


def classify_text(text: str) -> ClassificationResult:
    """Normaliza el texto, compara las categorías y devuelve la mejor."""

    if not isinstance(text, str) or not text.strip():
        raise ValueError("La descripción no puede estar vacía.")

    processed = preprocess_text(text)
    rule_results = {
        "IaaS": identify_iaas(processed.clean_text),
        "PaaS": identify_paas(processed.clean_text),
        "SaaS": identify_saas(processed.clean_text),
        "FaaS": identify_faas(processed.clean_text),
    }

    # Se suman reglas y conceptos; las reglas originales siguen siendo apoyo.
    results = {}
    for category, (rule_score, rule_matches) in rule_results.items():
        concept_score, concept_matches = score_concepts(processed.stems, category)
        matches = tuple(dict.fromkeys(rule_matches + concept_matches))
        results[category] = (rule_score + concept_score, matches)
    model = max(results, key=lambda category: results[category][0])
    score, concepts = results[model]

    if score == 0:
        return ClassificationResult("No clasificado", 0, ())
    return ClassificationResult(model, score, concepts)
