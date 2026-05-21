Config = {}

-- =====================================================================
--  QUÉ VEHÍCULOS SE PUEDEN CARGAR
-- =====================================================================
-- Clases de GTA V:  8 = Motos,  13 = Bicicletas,  9 = Quads/Offroad
-- "moto"  → Ocupa 1 slot lateral (caben 2)
-- "quad"  → Ocupa el slot central (cabe 1, la caja debe estar vacía)
Config.CargoClasses = {
    [8]  = "moto",   -- Motos
    [13] = "moto",   -- Bicicletas
    [9]  = "quad",   -- Quads / Offroad
}

-- =====================================================================
--  QUÉ VEHÍCULOS PUEDEN TRANSPORTAR (PICK-UPS)
-- =====================================================================
-- Cada pick-up tiene 3 slots definidos:
--   Slot 1 → Moto lado IZQUIERDO
--   Slot 2 → Moto lado DERECHO
--   Slot 3 → Quad CENTRAL (bloquea slots 1 y 2)
--
-- OFFSET = vector3(X, Y, Z):
--   X → Negativo = Izquierda | Positivo = Derecha
--   Y → Negativo = Atrás     | Positivo = Adelante
--   Z → Negativo = Abajo     | Positivo = Arriba
--
-- ROTATION = vector3(Pitch, Roll, Yaw):
--   En la mayoría de casos déjalo en 0.0, 0.0, 0.0
--
-- CÓMO AÑADIR TU PROPIO VEHÍCULO MOD:
--   1. Copia uno de los bloques de abajo
--   2. Cambia el nombre entre acentos graves [`nombre`] por el spawn name
--   3. Ajusta los offsets probando en el juego
-- =====================================================================

Config.TransporterVehicles = {

    -- ═══════════════════════════════════════
    --  Bravado Bison (spawn: bison)
    -- ═══════════════════════════════════════
    [`bison`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.35, -1.85, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.35, -1.85, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0,  -1.85, 0.6), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Vapid Sadler (spawn: sadler)
    -- ═══════════════════════════════════════
    [`sadler`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.40, -2.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.40, -2.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0,  -2.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Vapid Bobcat XL (spawn: bobcatxl)
    -- ═══════════════════════════════════════
    [`bobcatxl`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.35, -1.6, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.35, -1.6, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0,  -1.6, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Vapid Guardian (spawn: guardian)
    -- ═══════════════════════════════════════
    [`guardian`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.50, -2.2, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.50, -2.2, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0,  -2.2, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Benson (spawn: benson)
    -- ═══════════════════════════════════════
    [`benson`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.6, -0.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.6, -0.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3(-0.6, -2.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 4, type = "moto", offset = vector3( 0.6, -2.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 5, type = "moto", offset = vector3( 0.0, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 6, type = "quad", offset = vector3( 0.6, -2.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Flatbed (spawn: flatbed)
    -- ═══════════════════════════════════════
    [`flatbed`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.6, -1.0, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.6, -1.0, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3(-0.6, -3.0, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 4, type = "moto", offset = vector3( 0.6, -1.0, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 5, type = "moto", offset = vector3(-0.6, -2.0, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 6, type = "quad", offset = vector3( 0.6, -3.0, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 7, type = "moto", offset = vector3( 0.0, -1.0, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 8, type = "moto", offset = vector3( 0.6, -2.0, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 9, type = "quad", offset = vector3( 0.0, -3.0, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Dubsta 6x6 (spawn: dubsta3)
    -- ═══════════════════════════════════════
    [`dubsta3`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.4), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Rebel (spawn: rebel)
    -- ═══════════════════════════════════════
    [`rebel`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.35, -1.2, 0.5), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.35, -1.2, 0.5), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0,  -1.2, 0.5), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Sandking SWB (spawn: sandking)
    -- ═══════════════════════════════════════
    [`sandking`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -1.8, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -1.8, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -1.8, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Sandking XL (spawn: sandking2)
    -- ═══════════════════════════════════════
    [`sandking2`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -2.2, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -2.2, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -2.2, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Boat Trailer (spawn: boattrailer)
    -- ═══════════════════════════════════════
    [`boattrailer`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.25), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.25), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.25), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Scrap Truck (spawn: scrap)
    -- ═══════════════════════════════════════
    [`scrap`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.8), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Slamtruck (spawn: slamtruck)
    -- ═══════════════════════════════════════
    -- Tiene rampa inclinada, las motos irán con rotación para encajar.
    [`slamtruck`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -0.5, 0.5), rotation = vector3(10.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -0.5, 0.5), rotation = vector3(10.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -0.5, 0.5), rotation = vector3(10.0, 0.0, 0.0) },
            { id = 4, type = "moto", offset = vector3(-0.4, -0.5, 0.5), rotation = vector3(10.0, 0.0, 0.0) },
            { id = 5, type = "moto", offset = vector3( 0.4, -0.5, 0.5), rotation = vector3(10.0, 0.0, 0.0) },
            { id = 6, type = "quad", offset = vector3( 0.0, -0.5, 0.5), rotation = vector3(10.0, 0.0, 0.0) },
        }
    },

    -- ═══════════════════════════════════════
    --  Slamvan (spawn: slamvan)
    -- ═══════════════════════════════════════
    [`slamvan`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },
        [`slamvan3`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },
            [`yosemite`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },
                [`yosemite2`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
        }
    },
                [`yosemite3`] = {
        slots = {
            { id = 1, type = "moto", offset = vector3(-0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 2, type = "moto", offset = vector3( 0.4, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
            { id = 3, type = "quad", offset = vector3( 0.0, -1.5, 0.2), rotation = vector3(0.0, 0.0, 0.0) },
        }
    }
}


-- =====================================================================
--  AJUSTES GENERALES
-- =====================================================================

-- Si es true, los comandos de admin (/ajustar_slot, /forzar_descarga) solo
-- podrán usarlos jugadores con el ACE configurado en Config.AdminAce.
-- Si es false, cualquier jugador puede usarlos.
Config.AdminOnly = false
Config.AdminAce  = 'command'

-- Muestra la barra de progreso al cargar/descargar.
-- false → espera el tiempo en segundo plano sin ninguna barra visual.
Config.UseProgressbar = true

Config.LoadDuration   = 5000   -- ms que dura la barra de cargar
Config.UnloadDuration = 4000   -- ms que dura la barra de descargar
Config.SearchRadius   = 7.0    -- metros para encontrar la pick-up
Config.TargetDistance  = 3.5    -- distancia del ojito (qb-target)

-- Animación de mecánico (dict + clip + flags)
Config.Anim = {
    dict  = "mini@repair",
    clip  = "fixing_a_player",
    flags = 49,  -- 49 = loop + upper body
}

-- =====================================================================
--  AJUSTE DE ALTURA POR CLASE DE VEHÍCULO
--  Corrección de Z adicional al offset del slot según la clase GTA V.
--  Útil cuando el origen del modelo está más alto/bajo que la sanchez.
--  Clases: 8=Motos, 13=Bicicletas, 9=Quads/Offroad
-- =====================================================================
Config.ClassHeightAdjust = {
    [13] = 0.25,   -- Bicicletas: subir 0.25 para evitar que las ruedas atraviesen la caja
}

-- =====================================================================
--  CONTROLES DEL EDITOR DE ADMIN (/ajustar_slot)
--  Las teclas se configuran desde el menú de FiveM:
--  ESC → Ajustes → Controles → buscar "Editor Motos"
-- =====================================================================
