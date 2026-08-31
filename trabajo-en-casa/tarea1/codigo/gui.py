"""Interfaz gráfica Tkinter del clasificador Cloud."""

import tkinter as tk
from tkinter import messagebox, ttk

from classifier import classify_text


class CloudClassifierGUI:
    """Construye la ventana y delega la clasificación a classifier.py."""

    def __init__(self, root: tk.Tk) -> None:
        self.root = root
        self.root.title("Cloud Models Classifier - Python")
        self.root.geometry("760x570")
        self.root.minsize(650, 500)

        container = ttk.Frame(root, padding=20)
        container.pack(fill="both", expand=True)
        container.columnconfigure(1, weight=1)
        container.rowconfigure(4, weight=1)

        ttk.Label(container, text="Clasificador de modelos Cloud",
                  font=("Arial", 20, "bold")).grid(
            row=0, column=0, columnspan=2, pady=(0, 18)
        )

        ttk.Label(container, text="Nombre:").grid(row=1, column=0, sticky="w", pady=5)
        self.name_entry = ttk.Entry(container)
        self.name_entry.grid(row=1, column=1, sticky="ew", pady=5)

        ttk.Label(container, text="Apellido:").grid(row=2, column=0, sticky="w", pady=5)
        self.last_name_entry = ttk.Entry(container)
        self.last_name_entry.grid(row=2, column=1, sticky="ew", pady=5)

        ttk.Label(container, text="Descripción del servicio Cloud:").grid(
            row=3, column=0, columnspan=2, sticky="w", pady=(12, 5)
        )
        self.description_text = tk.Text(container, height=9, wrap="word",
                                        font=("Arial", 11))
        self.description_text.grid(row=4, column=0, columnspan=2, sticky="nsew")

        button_frame = ttk.Frame(container)
        button_frame.grid(row=5, column=0, columnspan=2, pady=15)
        ttk.Button(button_frame, text="Clasificar", command=self.classify).pack(
            side="left", padx=6
        )
        ttk.Button(button_frame, text="Limpiar", command=self.clear).pack(
            side="left", padx=6
        )

        self.result_label = ttk.Label(
            container, text="Esperando clasificación...", anchor="center",
            font=("Arial", 13, "bold"), padding=12
        )
        self.result_label.grid(row=6, column=0, columnspan=2, sticky="ew")
        self.name_entry.focus()

    def classify(self) -> None:
        """Valida la entrada, llama al clasificador y muestra el resultado."""

        name = self.name_entry.get().strip()
        last_name = self.last_name_entry.get().strip()
        description = self.description_text.get("1.0", "end").strip()

        if not name or not last_name or not description:
            messagebox.showwarning(
                "Datos incompletos",
                "Ingresa nombre, apellido y una descripción para continuar.",
            )
            return

        try:
            result = classify_text(description)
            concepts = ", ".join(result.matched_concepts) or "sin coincidencias"
            self.result_label.config(
                text=(f"Usuario: {name} {last_name}\n"
                      f"Modelo identificado: {result.model}\n"
                      f"Puntaje: {result.score}\n"
                      f"Conceptos: {concepts}")
            )
        except (ValueError, RuntimeError) as error:
            messagebox.showerror("Error", str(error))

    def clear(self) -> None:
        """Restablece los campos de la ventana."""

        self.name_entry.delete(0, "end")
        self.last_name_entry.delete(0, "end")
        self.description_text.delete("1.0", "end")
        self.result_label.config(text="Esperando clasificación...")
        self.name_entry.focus()


def main() -> None:
    root = tk.Tk()
    CloudClassifierGUI(root)
    root.mainloop()


if __name__ == "__main__":
    main()
