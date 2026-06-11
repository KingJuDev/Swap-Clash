extends SceneTree

const GarbageBlockScene := preload("res://scenes/GarbageBlock.tscn")

var _g: Variant = null

func _initialize() -> void:
	_g = GarbageBlockScene.instantiate()
	get_root().add_child(_g)

func _process(_delta: float) -> bool:
	var g: Variant = _g

	g.setup(3, 2, 64)
	assert(g.width == 3)
	assert(g.height == 2)
	assert(g.size == Vector2(192, 128))
	assert(g.color == Color(0.4, 0.4, 0.4))
	assert(g.state == GarbageBlock.State.IDLE)

	g.shrink_to(1, 64)
	assert(g.height == 1)
	assert(g.size == Vector2(192, 64))

	print("ALL TESTS PASSED")
	quit()
	return true
