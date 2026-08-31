# Prototipo Backend — Python + Flask

## Instalación

```bash
pip install flask
```

## Ejecución

```bash
python app.py
```

## Endpoints

```text
GET /health
GET /saldo/1001
POST /transferencia
```

## Ejemplo de transferencia

```json
{
  "origen": "1001",
  "destino": "2002",
  "monto": 500
}
```
