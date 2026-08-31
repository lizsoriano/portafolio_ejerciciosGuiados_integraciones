"""Interfaz de línea de comandos del clasificador Cloud."""

import argparse

from classifier import classify_text


def create_parser() -> argparse.ArgumentParser:
    """Define los argumentos requeridos por la aplicación."""

    parser = argparse.ArgumentParser(
        description="Clasifica una descripción como IaaS, PaaS, SaaS o FaaS."
    )
    parser.add_argument("--nombre", required=True, help="Nombre del usuario")
    parser.add_argument("--apellido", required=True, help="Apellido del usuario")
    parser.add_argument("--texto", required=True, help="Descripción del servicio Cloud")
    return parser


def main() -> None:
    args = create_parser().parse_args()

    # argparse valida que existan los argumentos; aquí se rechazan espacios vacíos.
    if not args.nombre.strip() or not args.apellido.strip() or not args.texto.strip():
        raise SystemExit("Error: nombre, apellido y texto no pueden estar vacíos.")

    try:
        result = classify_text(args.texto)
    except (ValueError, RuntimeError) as error:
        raise SystemExit(f"Error: {error}") from error

    concepts = ", ".join(result.matched_concepts) or "sin coincidencias"
    print(f"Nombre: {args.nombre.strip()} {args.apellido.strip()}")
    print(f"Modelo identificado: {result.model}")
    print(f"Puntuación: {result.score}")
    print(f"Conceptos encontrados: {concepts}")


if __name__ == "__main__":
    main()
