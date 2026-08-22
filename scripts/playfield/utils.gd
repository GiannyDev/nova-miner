class_name Utils

static func random_in_radius(radius: float = 1.0) -> Vector2:
	var r = sqrt(randf_range(0.0, 1.0)) * radius
	var t = randf_range(0.0, 1.0) * TAU
	return Vector2(r * cos(t), r * sin(t))


static func random_on_radius(radius: float = 1.0) -> Vector2:
	return Vector2.from_angle(randf_range(0, TAU)) * radius


static func random_direction() -> Vector2:
	return Vector2.from_angle(randf_range(0, TAU))


## Devuelve [param count] ángulos distribuidos uniformemente entre [param from_angle]
## (inclusive) y [param to_angle] (EXCLUSIVE — el último ángulo generado es
## [param to_angle] menos un paso). Útil para patrones radiales tipo shotgun spread
## o distribuir objetos en un arco/círculo sin duplicar el punto de inicio y fin.
static func subdivide_angle(from_angle: float, to_angle: float, count: int) -> Array[float]:
	assert(from_angle < to_angle, "from_angle debe ser menor que to_angle")
	assert(count > 0, "count debe ser mayor a 0")
	var angles: Array[float] = []
	angles.resize(count)
	
	var step: float = (to_angle - from_angle) / count
	for i in count:
		angles[i] = from_angle + step * i
	return angles


## Devuelve el vector perpendicular en sentido HORARIO (clockwise) a [param vector],
## con el mismo largo. Para sentido antihorario, usá el método nativo Vector2.orthogonal().
static func perp_cw(vector: Vector2) -> Vector2:
	return Vector2(vector.y, -vector.x)


static func get_all_children(node: Node) -> Array[Node]:
	var all_children: Array[Node] = []
	for i in node.get_child_count():
		var child: Node = node.get_child(i)
		all_children.append(child)
		if child.get_child_count() > 0:
			all_children.append_array(get_all_children(child))
	return all_children


static func hex(color: Color, with_alpha: bool = true) -> String:
	return "[color=%s]" % color.to_html(with_alpha)


static func colored(string: String, color: Color, with_alpha: bool = true) -> String:
	return hex(color, with_alpha) + string + "[/color]"


static func log_base(base: float, x: float) -> float:
	return log(x) / log(base)


static func weighted_random(weights: Array[float], rng: RandomNumberGenerator) -> int:
	return rng.rand_weighted(PackedFloat32Array(weights))


## 50% chance of either 1 or -1
static func flipi() -> int:
	return (randi() % 2) * 2 - 1


## Devuelve [code]true[/code] con una probabilidad de [param success] (0.0 a 1.0),
## y [code]false[/code] el resto de las veces. Por ejemplo, chance(0.3) tiene
## 30% de probabilidad de devolver true.
static func chance(success: float) -> bool:
	return randf() <= success


## Devuelve una lista de [param n] elementos únicos elegidos al azar de [param list],
## sin repetir ningún elemento ni modificar el array original. Usa el algoritmo de
## reservoir sampling (Algoritmo S de Knuth), O(n), sin necesidad de barajar el array completo.
static func sample(list: Array, n: int) -> Array:
	var needed: int = n
	var remaining: int = list.size()
	var chosen: Array = []
	
	for i in range(list.size()):
		if needed == 0: break
		var prob: float = float(needed) / remaining
		if chance(prob):
			chosen.append(list[i])
			needed -= 1
		remaining -= 1
	return chosen
