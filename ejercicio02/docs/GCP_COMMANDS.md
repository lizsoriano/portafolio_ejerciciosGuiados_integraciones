# Comandos de infraestructura — GCP SDK CLI

Este documento registra los comandos de `gcloud` para crear la instancia
Compute Engine con CentOS Stream 10 pedida en la Parte 4, punto 9 del
enunciado, y la configuración de firewall asociada.

**Estado de evidencia**: estos comandos están listos para ejecutarse pero
NO fueron ejecutados desde esta sesión de trabajo — este entorno no tiene
acceso a `gcloud` ni a una cuenta de GCP real. No se incluye aquí ninguna
captura, IP, ID de proyecto ni salida de comando como si hubiera ocurrido:
eso lo debe generar y documentar quien ejecute estos comandos contra su
propio proyecto, como evidencia real (`docs/PROGRESS.md` lo deja marcado
como pendiente).

Reemplace `YOUR_PROJECT_ID`, `YOUR_INSTANCE_NAME` y las demás variables
`YOUR_*` por los valores reales de su proyecto antes de ejecutar.

## 1. Requisitos previos

```bash
gcloud --version
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
```

## 2. Región, zona y dimensionamiento

- **Región/zona**: `us-central1-a` (o la más cercana/económica en su
  cuenta; cualquier región con `e2` disponible sirve para este ejercicio).
- **Tipo de máquina**: `e2-small` (2 vCPU compartidas, 2 GB RAM).
- **Justificación del dimensionamiento**: la carga esperada es la de un
  ejercicio académico con un solo proceso Node.js (Express + EJS),
  PostgreSQL en la misma instancia y sin tráfico concurrente significativo.
  `e2-small` cubre Node + PostgreSQL + Apache/NGINX simultáneos sin
  sobreaprovisionar; si `psql`/pruebas muestran presión de memoria, subir a
  `e2-medium` (4 GB RAM) es un cambio de una sola bandera
  (`--machine-type`), no un rediseño.
- **Disco**: 20 GB `pd-balanced` es suficiente para SO + PostgreSQL +
  `node_modules` + `uploads/` de prueba.
- **Imagen**: familia `centos-stream-10` del proyecto público `centos-cloud`.

## 3. Red y firewall

Sólo se expone HTTP/HTTPS (mediante el reverse proxy) y SSH; PostgreSQL y
Node **no** deben quedar accesibles desde internet.

```bash
# Firewall: permitir HTTP/HTTPS solo a instancias con la etiqueta web-server
gcloud compute firewall-rules create allow-http-https \
  --network=default \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:80,tcp:443 \
  --target-tags=web-server \
  --source-ranges=0.0.0.0/0

# SSH: restringir en lo posible a su propia IP en vez de 0.0.0.0/0
gcloud compute firewall-rules create allow-ssh \
  --network=default \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:22 \
  --target-tags=web-server \
  --source-ranges=YOUR_IP/32
```

No se crea ninguna regla para el puerto 3000 (Node) ni 5432 (PostgreSQL):
ambos permanecen accesibles solo dentro de la instancia (`127.0.0.1`),
conforme a la Parte 8, punto 19 del enunciado.

## 4. Crear la instancia

```bash
gcloud compute instances create YOUR_INSTANCE_NAME \
  --zone=us-central1-a \
  --machine-type=e2-small \
  --image-family=centos-stream-10 \
  --image-project=centos-cloud \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-balanced \
  --tags=web-server
```

## 5. Verificar la instancia (después de crearla)

```bash
gcloud compute instances describe YOUR_INSTANCE_NAME --zone=us-central1-a \
  --format='value(status,networkInterfaces[0].accessConfigs[0].natIP)'

gcloud compute ssh YOUR_INSTANCE_NAME --zone=us-central1-a
```

El segundo comando abre una sesión SSH interactiva; a partir de ahí, las
instrucciones de instalación y sincronización continúan en
[`docs/INSTRUCCIONES_INSTANCIA_GCP.md`](INSTRUCCIONES_INSTANCIA_GCP.md).

## 6. Limpieza (solo si se necesita recrear el entorno)

```bash
gcloud compute instances delete YOUR_INSTANCE_NAME --zone=us-central1-a
```

No ejecute este comando salvo que explícitamente quiera destruir la
instancia; no es parte del flujo normal de despliegue.

## 7. Despliegue real ejecutado (2026-08-31)

Todo lo anterior en este archivo (secciones 1-6) es la plantilla de
comandos lista para ejecutarse, escrita antes de tener acceso real a la
instancia. Esta sección documenta lo que **sí se ejecutó de verdad** el
2026-08-31 contra la instancia ya existente del usuario, con valores
reales (no placeholders):

- Instancia: `maquina-02`, zona `northamerica-south1-c`, proyecto
  `integracion-sistemas-637044`, tipo `e2-standard-2`, IP externa
  `34.51.61.250`, SO CentOS Stream 10 (`cat /etc/os-release`).
- PostgreSQL y Node.js ya estaban instalados en la instancia; el
  proyecto se sincronizó como `git clone` fresco en
  `/opt/udem/integracion02` (ver `ENGINEERING_DECISIONS.md` para el
  detalle de por qué se abandonó un checkout previo desactualizado en
  `/opt/web_library`).
- Firewall: se agregó una regla nueva para NGINX y se identificó (sin
  poder eliminarla por permisos de la sesión de trabajo) una regla vieja
  que exponía Node directamente:

```bash
gcloud compute firewall-rules create allow-library-http \
  --allow=tcp:80 --source-ranges=0.0.0.0/0 \
  --description="Reverse proxy NGINX para /library (Ejercicio Guiado 02)"

# Regla vieja que exponia Node directo al puerto 3000: eliminada.
gcloud compute firewall-rules delete monolito-web --quiet
```

- Servicio `systemd` para Node (`/etc/systemd/system/library-web.service`),
  escuchando solo en `127.0.0.1:3000` (ver ED-14):

```ini
[Unit]
Description=Libreria Web - Ejercicio Guiado 02 (Node.js/Express, solo 127.0.0.1:3000)
After=network.target postgresql.service

[Service]
Type=simple
User=rutil
WorkingDirectory=/opt/udem/integracion02/apps/web-monolito
ExecStart=/usr/bin/node src/server.js
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now library-web
```

- NGINX como reverse proxy (`/etc/nginx/default.d/library-proxy.conf`,
  se agrega dentro del server block por defecto que ya trae el paquete
  `nginx` de CentOS Stream 10):

```nginx
location /library {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

```bash
sudo dnf install -y nginx
sudo setsebool -P httpd_can_network_connect 1   # requerido por SELinux Enforcing, ver ED-15
sudo systemctl enable --now nginx
```

- Verificación real ejecutada, desde fuera de la instancia:

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://34.51.61.250/library
# 301
curl -sL http://34.51.61.250/library | head -c 300
# HTML real del catalogo, con libros del seed y rutas /library/...
curl -s -o /dev/null -w '%{http_code}\n' -m 5 http://34.51.61.250:3000/library
# sin conexion: el puerto 3000 ya no es publico
```
