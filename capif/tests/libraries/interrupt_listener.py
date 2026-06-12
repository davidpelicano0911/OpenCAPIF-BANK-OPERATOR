import signal
from robot.libraries.BuiltIn import BuiltIn

class InterruptListener:
    ROBOT_LISTENER_API_VERSION = 3

    def __init__(self):
        signal.signal(signal.SIGINT, self._handle_interrupt)
        self.builtin = BuiltIn()

    def _handle_interrupt(self, signum, frame):
        print("Execution interrupted! Running cleanup keyword...")
        try:
            self.builtin.run_keyword('Reset Testing Environment')
        except Exception as e:
            print(f"Error during cleanup: {e}")
        finally:
            exit(0)
    
    def start_suite(self, name, attrs):
        print(f"Starting suite: {name}")

    def end_suite(self, name, attrs):
        print(f"Ending suite: {name}")


INTERRUPT_LISTENER=InterruptListener()

def hello_world():
    print("Hello, world!")