"""Pruebas formales del clasificador usando la biblioteca estándar."""

import unittest

from classifier import classify_text


class CloudClassifierTests(unittest.TestCase):

    def test_iaas(self) -> None:
        result = classify_text(
            "Necesito máquinas virtuales, almacenamiento y redes configurables."
        )
        self.assertEqual(result.model, "IaaS")

    def test_paas(self) -> None:
        result = classify_text(
            "Quiero desplegar mi aplicación web en una plataforma de desarrollo."
        )
        self.assertEqual(result.model, "PaaS")

    def test_saas(self) -> None:
        result = classify_text(
            "Correo electrónico desde el navegador con suscripción mensual."
        )
        self.assertEqual(result.model, "SaaS")

    def test_faas(self) -> None:
        result = classify_text(
            "Ejecutar una función serverless automáticamente por un evento."
        )
        self.assertEqual(result.model, "FaaS")

    def test_without_enough_evidence(self) -> None:
        result = classify_text("Necesito una solución moderna para mi empresa.")
        self.assertEqual(result.model, "No clasificado")

    def test_empty_text_is_invalid(self) -> None:
        with self.assertRaises(ValueError):
            classify_text("   ")


if __name__ == "__main__":
    unittest.main()
