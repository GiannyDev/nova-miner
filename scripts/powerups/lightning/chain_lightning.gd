extends Chainer
class_name ChainLightning
## Rayo que salta de bloque en bloque. Esta clase SOLO pinta un hop.
## El loop (Player / skill) pide la cadena, espera, aplica DMG, y pide el siguiente.
##
## Flujo de un hop:
## 1. El caller tiene `from` (player o bloque anterior) y un `ore` vivo.
## 2. `chain()` spawnea el Line2D electrico via Effects (de from → ore).
## 3. El caller aplica `ore.take_damage(dmg)` cuando el hop ya esta en pantalla.
## 4. El caller espera `time_between_chains()` y pasa al siguiente ore de la lista.
##
## El loop pide UN hop a la vez: `get_chain_ore(from_cell, max_cells, exclude)`.
## Asi el siguiente bloque se elige en vivo (igual quieto o en movimiento).
## UpgradeTree: mas DMG + mas hops + `max_cells`.


const BOLT_COLOR := Color("7cd4f8")
const BOLT_WIDTH := 28.0
const BOLT_DURATION := 0.28
const HOP_DELAY := 0.08
const HOP_PUNCH := 7.0


## Pinta un rayo from → ore y espera a que el trazo exista un frame.
func chain(from: Vector2, ore: Ore) -> void:
	if ore == null or not is_instance_valid(ore):
		return
	var target := ore.global_position
	Effects.electricity(from, target, BOLT_COLOR, BOLT_WIDTH, BOLT_DURATION)
	if Refs.camera != null:
		Refs.camera.punch(target - from, HOP_PUNCH)
	await get_tree().process_frame


func time_between_chains() -> float:
	return HOP_DELAY
