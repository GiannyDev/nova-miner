extends Node2D
class_name Chainer
## Un hop visual de A → bloque. ChainLightning / otros skills lo implementan.
## El loop (quien llama) decide cuantos hops, el dano y el delay.


## Dibuja el hop. Awaitable: el caller puede `await chainer.chain(...)`.
func chain(_from: Vector2, _ore: Ore) -> void:
	pass


## Pausa entre hops. El skill lo espera despues de aplicar dano.
func time_between_chains() -> float:
	return 0.0
