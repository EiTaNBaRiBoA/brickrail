
import asyncio

from pybricksdev.ble import find_device

from ble_hub import BLEHub

def const(x):
    return x

_COLOR_YELLOW = const(0)
_COLOR_BLUE   = const(1)
_COLOR_GREEN  = const(2)
_COLOR_RED    = const(3)
_COLOR_NONE   = const(15)
COLOR_HUES = (31, 199, 113, 339)

_SENSOR_KEY_NONE  = const(0)
_SENSOR_KEY_ENTER = const(1)
_SENSOR_KEY_IN    = const(2)

_SENSOR_SPEED_FAST = const(1)
_SENSOR_SPEED_SLOW = const(2)
_SENSOR_SPEED_CRUISE = const(3)

_LEG_TYPE_TRAVEL = const(0)
_LEG_TYPE_FLIP   = const(1)
_LEG_TYPE_START  = const(2)

_BEHAVIOR_IGNORE      = const(0)
_BEHAVIOR_SLOW        = const(1)
_BEHAVIOR_CRUISE      = const(2)
_BEHAVIOR_STOP        = const(3)
_BEHAVIOR_FLIP_CRUISE = const(4)
_BEHAVIOR_FLIP_SLOW   = const(5)

_INTENTION_STOP = const(0)
_INTENTION_PASS = const(1)

_CONFIG_CHROMA_THRESHOLD   = const(0)
_CONFIG_MOTOR_ACC          = const(1)
_CONFIG_MOTOR_DEC          = const(2)
_CONFIG_MOTOR_FAST_SPEED   = const(3)
_CONFIG_MOTOR_SLOW_SPEED   = const(4)
_CONFIG_MOTOR_CRUISE_SPEED = const(5)

_DATA_STATE_CHANGED  = const(0)
_DATA_ROUTE_COMPLETE = const(1)
_DATA_LEG_ADVANCE    = const(2)
_DATA_SENSOR_ADVANCE = const(3)

_STATE_STOPPED = const(0)
_STATE_SLOW    = const(1)
_STATE_CRUISE  = const(2)

def create_leg_data(colors, keys, speeds, plan, leg_type):
    data = bytearray()
    for color, key, speed in zip(colors, keys, speeds):
        composite = (speed << 6) + (key << 4) + color
        data.append(composite)
    composite = leg_type + (plan << 4)
    data.append(composite)
    return data

async def test_motor(train):
    await asyncio.sleep(1)
    await train.rpc("start")
    await asyncio.sleep(4)
    await train.rpc("slow")
    await asyncio.sleep(2)
    await train.rpc("stop")

def on_data(data):
    id = data[0]
    arg = data[1]

    if id == _DATA_SENSOR_ADVANCE:
        print(f"train advanced sensor {arg}")
    if id == _DATA_LEG_ADVANCE:
        print(f"train advanced leg {arg}")
    if id == _DATA_ROUTE_COMPLETE:
        print(f"train completed route")

async def test_route_flip(train):
    await asyncio.sleep(1)
    await train.rpc("new_route")
    await train.rpc("set_route_leg", b"\x01" + create_leg_data(
        (_COLOR_BLUE,       _COLOR_BLUE),
        (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
        (_SENSOR_SPEED_CRUISE, _SENSOR_SPEED_CRUISE),
        _INTENTION_PASS, _LEG_TYPE_TRAVEL))
    await train.rpc("set_route_leg", b"\x02" + create_leg_data(
        (_COLOR_BLUE,),
        (_SENSOR_KEY_IN,),
        (_SENSOR_SPEED_CRUISE,),
        _INTENTION_PASS, _LEG_TYPE_FLIP))
    await train.rpc("advance_route")
    await train.rpc("set_route_leg", b"\x03" + create_leg_data(
        (_COLOR_BLUE, _COLOR_BLUE,),
        (_SENSOR_KEY_NONE, _SENSOR_KEY_IN,),
        (_SENSOR_SPEED_CRUISE, _SENSOR_SPEED_CRUISE),
        _INTENTION_PASS, _LEG_TYPE_TRAVEL))
    await train.rpc("set_route_leg", b"\x04" + create_leg_data(
        (_COLOR_BLUE,),
        (_SENSOR_KEY_IN,),
        (_SENSOR_SPEED_CRUISE,),
        _INTENTION_STOP, _LEG_TYPE_FLIP))
    await train.wait_for_data_id(_DATA_ROUTE_COMPLETE)

async def test_route_loop(train):
    await asyncio.sleep(1)
    await train.rpc("new_route")
    await train.rpc("set_route_leg", b"\x01" + create_leg_data(
        (_COLOR_BLUE,       _COLOR_BLUE),
        (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
        (_SENSOR_SPEED_CRUISE, _SENSOR_SPEED_CRUISE),
        _INTENTION_PASS, _LEG_TYPE_TRAVEL))
    await train.rpc("advance_route")
    await train.rpc("set_route_leg", b"\x02" + create_leg_data(
        (_COLOR_RED, _COLOR_BLUE,),
        (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN,),
        (_SENSOR_SPEED_CRUISE, _SENSOR_SPEED_CRUISE),
        _INTENTION_STOP, _LEG_TYPE_TRAVEL))
    await train.wait_for_data_id(_DATA_ROUTE_COMPLETE)

async def test_route_loop_gradient(train):
    await asyncio.sleep(1)
    await train.rpc("new_route")
    await train.rpc("set_route_leg", b"\x01" + create_leg_data(
        (_COLOR_BLUE,       _COLOR_BLUE),
        (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
        (_SENSOR_SPEED_FAST, _SENSOR_SPEED_CRUISE),
        _INTENTION_PASS, _LEG_TYPE_TRAVEL))
    await train.rpc("advance_route")
    await train.rpc("set_route_leg", b"\x02" + create_leg_data(
        (_COLOR_RED, _COLOR_BLUE,),
        (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN,),
        (_SENSOR_SPEED_SLOW, _SENSOR_SPEED_CRUISE),
        _INTENTION_STOP, _LEG_TYPE_TRAVEL))
    await train.wait_for_data_id(_DATA_ROUTE_COMPLETE)

async def test_route_loops_gradient(train):
    await asyncio.sleep(1)
    await train.rpc("new_route")
    for i in range(3):
        print(i)
        await train.rpc("set_route_leg", bytes([2*i+1]) + create_leg_data(
            (_COLOR_BLUE,       _COLOR_BLUE),
            (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
            (_SENSOR_SPEED_FAST, _SENSOR_SPEED_CRUISE),
            _INTENTION_PASS, _LEG_TYPE_TRAVEL))
        await train.rpc("set_route_leg", bytes([2*i+2]) + create_leg_data(
            (_COLOR_RED, _COLOR_BLUE,),
            (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN,),
            (_SENSOR_SPEED_SLOW, _SENSOR_SPEED_CRUISE),
            _INTENTION_PASS, _LEG_TYPE_TRAVEL))
    i+=1
    await train.rpc("set_route_leg", bytes([2*i+1]) + create_leg_data(
        (_COLOR_BLUE,       _COLOR_BLUE),
        (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
        (_SENSOR_SPEED_FAST, _SENSOR_SPEED_CRUISE),
        _INTENTION_PASS, _LEG_TYPE_TRAVEL))
    await train.rpc("set_route_leg", bytes([2*i+2]) + create_leg_data(
        (_COLOR_RED, _COLOR_BLUE,),
        (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN,),
        (_SENSOR_SPEED_SLOW, _SENSOR_SPEED_CRUISE),
        _INTENTION_STOP, _LEG_TYPE_TRAVEL))
    await train.rpc("advance_route")
    await train.wait_for_data_id(_DATA_ROUTE_COMPLETE)

async def test_simple_speed(train):
    await asyncio.sleep(1)
    await train.rpc("new_route")
    await train.rpc("set_route_leg", bytes([1]) + create_leg_data(
            (_COLOR_BLUE,       _COLOR_BLUE),
            (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN),
            (_SENSOR_SPEED_FAST, _SENSOR_SPEED_CRUISE),
            _INTENTION_PASS, _LEG_TYPE_TRAVEL))
    await train.rpc("set_route_leg", bytes([2]) + create_leg_data(
            (_COLOR_RED, _COLOR_BLUE,),
            (_SENSOR_KEY_ENTER, _SENSOR_KEY_IN,),
            (_SENSOR_SPEED_SLOW, _SENSOR_SPEED_CRUISE),
            _INTENTION_STOP, _LEG_TYPE_TRAVEL))
    await train.rpc("advance_route")
    await train.wait_for_data_id(_DATA_ROUTE_COMPLETE)

async def main():
    train = BLEHub()
    dev = await find_device()
    print(dev)
    await train.connect(dev)
    try:
        await train.run("smart_train")
        await train.store_value(_CONFIG_MOTOR_CRUISE_SPEED, 75)
        await train.store_value(_CONFIG_MOTOR_FAST_SPEED, 100)
        await train.store_value(_CONFIG_MOTOR_ACC, 1000)
        await train.store_value(_CONFIG_MOTOR_DEC, 1000)
        with train.data_subject.subscribe(on_data):
            # await test_route_loops_gradient(train)
            await test_simple_speed(train)
        
        await train.stop_program()
    finally:
        await train.disconnect()

asyncio.run(main())