extends SceneTree

const BlockScene := preload("res://scenes/Block.tscn")
const GarbageBlockScene := preload("res://scenes/GarbageBlock.tscn")

var _b: Variant = null
var _g: Variant = null

func _initialize() -> void:
	_b = BlockScene.instantiate()
	get_root().add_child(_b)
	_g = GarbageBlockScene.instantiate()
	get_root().add_child(_g)
	_g.setup(1, 1, 64)

func _process(_delta: float) -> bool:
	var b: Variant = _b
	var g: Variant = _g

	# New Block fields/states.
	assert(b.state == Block.State.IDLE)
	assert(b.from_chain == false)
	assert(b.float_timer == 0.0)
	assert(b.state_timer == 0.0)
	var floating_state: int = Block.State.FLOATING
	assert(floating_state != Block.State.IDLE)

	# play_land_squash must exist and be callable without crashing.
	b.play_land_squash()

	# New GarbageBlock fields/states.
	assert(g.float_timer == 0.0)
	var garbage_floating_state: int = GarbageBlock.State.FLOATING
	assert(garbage_floating_state != GarbageBlock.State.IDLE)

	print("ALL TESTS PASSED")
	quit()
	return true
