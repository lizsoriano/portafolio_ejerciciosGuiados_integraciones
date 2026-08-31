from flask import Flask, jsonify, request

app = Flask(__name__)

usuarios = {
    "1001": {
        "nombre": "Juan",
        "saldo": 15250.75
    }
}


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "service": "mobile-banking-api"
    }), 200


@app.route("/saldo/<usuario_id>", methods=["GET"])
def consultar_saldo(usuario_id):

    usuario = usuarios.get(usuario_id)

    if usuario is None:
        return jsonify({
            "error": "Usuario no encontrado"
        }), 404

    return jsonify({
        "usuario": usuario_id,
        "nombre": usuario["nombre"],
        "saldo": usuario["saldo"]
    }), 200


@app.route("/transferencia", methods=["POST"])
def transferencia():

    datos = request.get_json()

    if not datos:
        return jsonify({
            "error": "Solicitud inválida"
        }), 400

    origen = datos.get("origen")
    destino = datos.get("destino")
    monto = datos.get("monto")

    if not origen or not destino or monto is None:
        return jsonify({
            "error": "Faltan datos requeridos"
        }), 400

    try:
        monto = float(monto)
    except (ValueError, TypeError):
        return jsonify({
            "error": "Monto inválido"
        }), 400

    if monto <= 0:
        return jsonify({
            "error": "El monto debe ser mayor a cero"
        }), 400

    return jsonify({
        "mensaje": "Transferencia recibida para procesamiento",
        "origen": origen,
        "destino": destino,
        "monto": monto
    }), 202


if __name__ == "__main__":
    app.run(debug=True)
