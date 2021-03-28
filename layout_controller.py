from pybricks.hubs import TechnicHub
from pybricks.pupdevices import ColorDistanceSensor, DCMotor, Motor
from pybricks.parameters import Port, Color
from pybricks.tools import wait, StopWatch
from pybricks.experimental import getchar

delta = 0.03

class Timer:

    timers = []

    def __init__(self):
        self.watch = StopWatch()
        self.watch.pause()
        self.time = None
        self.callback = None

        Timer.timers.append(self)
    
    def arm(self, time, callback):
        self.watch.reset()
        self.watch.resume()
        self.time = time
        self.callback = callback 
    
    def update(self):
        if self.time is None:
            return
        if self.watch.time()>self.time:
            self.watch.pause()
            self.watch.reset()
            self.callback()
            self.time = None
            self.callback = None

class Switch:
    def __init__(self, name, port, pulse_duration = 0.2):
        self.name = name
        self.motor = Motor(port)
        self.position = "unknown"
        self.port = port
        self.pulse_duration = pulse_duration
        self.switch_timer = Timer()

    
    def send_data(self, key, data):
        obj = {"device": self.name, "key": key, "data": data}
        send_data("device_data", obj)
    
    def switch(self, position):
        assert position in ["left", "right"]
        if position == self.position:
            return
        sdir = -1
        if position == "left":
            sdir = 1
        self.motor.run(100*sdir)
        self.switch_timer.arm(self.pulse_duration, self.on_switch_timer)
        self.position = "switching_"+position
    
    def on_switch_timer(self):
        
        if self.position == "switching_left":
            self.position = "left"
        elif self.position == "switing_right":
            self.position = "right"
        else:
            print("Controller device", self.name, "got a problem!! self.position=",self.position)
        self.motor.stop()
        self.send_data("position_changed", self.position)
    
    def update(self, delta):
        pass

class Controller:

    def __init__(self):
        self.hub = TechnicHub()
        self.devices = {}

    def attached_ports(self):
        ports = []
        for dev in self.devices.values():
            ports.append(dev.port)
    
    def attach_device(self, device):
        assert device.port not in self.attached_ports
        assert device.port<=Port.D

        self.devices[device.name] = device
    
    def update(self, delta):
        for device in self.devices.values():
            device.update(delta)

controller = Controller()

def timer_update():
    for timer in Timer.timers:
        timer.update()

def input_handler(message):
    print(repr(message))
    try:
        eval(message)
    except SyntaxError as e:
        print(e)

def send_data(key, data):
    obj = {"key": key, "data": data}
    msg = "data::"+repr(obj)
    print(msg)

def control_loop():
    timer_update()
    controller.update(delta)


test_data = {"xd": ["some", "strings"], "lol": [None]}
send_data("test_id", test_data)

while True:
    timeout = int(delta*1000)
    wait(timeout)
    message = ""
    #if loop_poll.poll(timeout):
    char = getchar()
    while char is not None:
        char = chr(char)
        message += char
        char = getchar()
    if message:
        input_handler(message)
    control_loop()