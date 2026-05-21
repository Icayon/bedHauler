# BedHauler — FiveM Resource

> **Load motorcycles & quads onto pickup trucks / Carga motos y quads en pick-ups**

Compatible with **QBCore · QBox · ESX · Standalone**  
Supports **qb-target · ox_target · bt-target** (falls back to key `E`)

---

## English

### What does it do?

BedHauler lets players load motorcycles, bicycles, and quads into the bed of pickup trucks or flatbeds. Each transporter has numbered slots with precise positions. Vehicles are physically attached to the truck, locked, and secured with a visual strap prop.

### Features

- Load / unload motorcycles (class 8), bicycles (class 13), and quads (class 9)
- Multiple slots per transporter — up to 9 on large vehicles (Flatbed, Benson)
- Moto slots (left / right) and Quad slots (central — blocks moto slots)
- Visual strap prop (`dwk_moto_rope`) attached locally on each client
- Progress bar with mechanic animation during loading/unloading
- Camera cinematic view during the operation
- Auto-detach if the truck rolls over 75°
- Tailgate opens/closes automatically on supported vehicles
- Export `HasCargo(transportVeh)` for garage systems
- **In-game slot editor** for admins (`/ajustar_slot <slotId>`)
- Multi-framework auto-detection (no config needed)

### Supported transporter vehicles (default)

| Vehicle | Spawn name | Slots |
|---|---|---|
| Bravado Bison | `bison` | 3 |
| Vapid Sadler | `sadler` | 3 |
| Vapid Bobcat XL | `bobcatxl` | 3 |
| Vapid Guardian | `guardian` | 3 |
| Benson | `benson` | 6 |
| Flatbed | `flatbed` | 9 |
| Dubsta 6x6 | `dubsta3` | 3 |
| Rebel | `rebel` | 3 |
| Sandking SWB | `sandking` | 3 |
| Sandking XL | `sandking2` | 3 |
| Boat Trailer | `boattrailer` | 3 |
| Scrap Truck | `scrap` | 3 |
| Slamtruck | `slamtruck` | 6 |
| Slamvan | `slamvan` | 3 |
| Yosemite (all) | `yosemite/2/3` | 3 |

### Installation

1. Copy the `bedHauler` folder into your server's `resources` directory.
2. Add `ensure bedHauler` to your `server.cfg`.
3. Start the server — framework and target system are detected automatically.

### Configuration (`config.lua`)

```lua
Config.UseProgressbar  = true    -- show progress bar
Config.LoadDuration    = 5000    -- ms to load
Config.UnloadDuration  = 4000    -- ms to unload
Config.SearchRadius    = 7.0     -- meters to find a transporter
Config.TargetDistance  = 3.5     -- target eye distance
Config.AdminOnly       = false   -- restrict admin commands
```

**Adding a custom vehicle:**
```lua
[`yourspawnname`] = {
    slots = {
        { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
        { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
        { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
    }
},
```

### Admin commands

| Command | Description |
|---|---|
| `/ajustar_slot <id>` | Open the in-game slot position editor |
| `/forzar_descarga [plate]` | Force unload all cargo (or by truck plate) |

**Editor controls (while `/ajustar_slot` is open):**

| Key | Action |
|---|---|
| Arrow keys | Move position (X/Y) |
| Page Up / Page Down | Move up / down (Z) |
| U / O | Yaw left / right |
| I / K | Pitch forward / back |
| J / L | Roll left / right |
| Left Shift | Speed ×5 |
| G | Toggle ghost vehicle preview |
| Enter | Confirm / next phase |
| Backspace | Cancel |

### How it works internally

1. **State bags** (`cargoSlot`) sync cargo state across all clients without scanning the full vehicle pool.
2. A **transporter cache** (refreshed every 5 s) avoids calling `GetGamePool` on every interaction.
3. The **slot conflict system** prevents placing a quad where motos exist and vice versa, grouped by "plaza" (every 3 slots).
4. Strap props are **local-only** (not networked) to minimize entity usage.
5. The server validates load distance to prevent exploit abuse.
6. `custom_offsets.lua` is auto-written by the editor and merged into `Config.TransporterVehicles` at runtime.

---

## Español

### ¿Qué hace?

BedHauler permite a los jugadores cargar motos, bicicletas y quads en la caja de pick-ups o camiones plataforma. Cada vehículo transportador tiene slots numerados con posiciones precisas. Los vehículos se adjuntan físicamente al camión, se bloquean y se sujetan con un prop visual de amarre.

### Características

- Cargar / descargar motos (clase 8), bicicletas (clase 13) y quads (clase 9)
- Múltiples slots por transportador — hasta 9 en vehículos grandes (Flatbed, Benson)
- Slots de moto (izquierdo / derecho) y slots de quad (central — bloquea los de moto)
- Prop visual de amarre (`dwk_moto_rope`) adjunto localmente en cada cliente
- Barra de progreso con animación de mecánico durante la carga/descarga
- Vista de cámara cinemática durante la operación
- Desenganche automático si el camión vuelca más de 75°
- El portón trasero se abre/cierra automáticamente en los vehículos compatibles
- Export `HasCargo(transportVeh)` para sistemas de garajes
- **Editor de slots en juego** para admins (`/ajustar_slot <slotId>`)
- Detección automática de framework (no requiere configuración)

### Instalación

1. Copia la carpeta `bedHauler` dentro de la carpeta `resources` de tu servidor.
2. Agrega `ensure bedHauler` en tu `server.cfg`.
3. Inicia el servidor — el framework y el sistema de targeting se detectan solos.

### Configuración (`config.lua`)

```lua
Config.UseProgressbar  = true    -- mostrar barra de progreso
Config.LoadDuration    = 5000    -- ms que dura la carga
Config.UnloadDuration  = 4000    -- ms que dura la descarga
Config.SearchRadius    = 7.0     -- metros para buscar una pick-up
Config.TargetDistance  = 3.5     -- distancia del ojito (target)
Config.AdminOnly       = false   -- restringir comandos admin al ACE
```

**Añadir un vehículo personalizado:**
```lua
[`tuSpawnName`] = {
    slots = {
        { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
        { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
        { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
    }
},
```

**Offsets explicados:**
- `X` negativo = izquierda · positivo = derecha
- `Y` negativo = atrás · positivo = adelante
- `Z` negativo = abajo · positivo = arriba

### Comandos de admin

| Comando | Descripción |
|---|---|
| `/ajustar_slot <id>` | Abre el editor de posición del slot en juego |
| `/forzar_descarga [matricula]` | Fuerza la descarga de todo (o por matrícula del camión) |

### Cómo funciona internamente

1. **State bags** (`cargoSlot`) sincronizan el estado de carga entre todos los clientes sin escanear el pool completo de vehículos.
2. Un **caché de transportadores** (refrescado cada 5 s) evita llamar a `GetGamePool` en cada interacción.
3. El **sistema de conflictos de plaza** evita poner un quad donde hay motos y viceversa, agrupando cada 3 slots.
4. Los props de amarre son **locales** (no de red) para minimizar el uso de entidades.
5. El servidor valida la distancia de carga para evitar abusos.
6. `custom_offsets.lua` es escrito automáticamente por el editor y se fusiona con `Config.TransporterVehicles` en tiempo de ejecución.

---

## File structure / Estructura de archivos

```
bedHauler/
├── fxmanifest.lua        # Resource manifest
├── config.lua            # Vehicle slots and general settings
├── client.lua            # Client-side logic (load, unload, editor, sync)
├── server.lua            # Server-side validation, logging, commands
├── bridge_client.lua     # Framework/target abstraction (client)
├── bridge_server.lua     # Framework abstraction (server)
├── custom_offsets.lua    # Auto-generated by /ajustar_slot editor
└── stream/
    ├── dwk_moto_rope.ydr # Strap prop model
    └── dwk_moto_rope.ytyp
```

---

*Author: SKIZO (Universal Version)*
