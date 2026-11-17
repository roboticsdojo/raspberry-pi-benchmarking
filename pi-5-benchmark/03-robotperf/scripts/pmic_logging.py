"""Background PMIC power logger for the Raspberry Pi 5.

The Pi 5 has no INA3221 (Jetson) power sensors, so RobotPerf's power metrics are
approximated by polling the PMIC ADC through `vcgencmd pmic_read_adc`.

Each CSV row is `unix_timestamp,pmic_raw`, where pmic_raw is the multi-line
vcgencmd output joined with ' | ' so every sample stays on one row.
"""
import subprocess
import threading
import time


class PmicLogger:
    def __init__(self, log_file, period_s=0.2):
        self.log_file = log_file
        self.period_s = period_s
        self._stop = threading.Event()
        self._thread = None

    def _run(self):
        with open(self.log_file, 'w') as f:
            f.write('unix_timestamp,pmic_raw\n')
            while not self._stop.is_set():
                try:
                    raw = subprocess.check_output(
                        ['vcgencmd', 'pmic_read_adc'], stderr=subprocess.DEVNULL
                    ).decode()
                except (FileNotFoundError, subprocess.CalledProcessError):
                    f.write(f'{time.time()},UNAVAILABLE\n')
                    print('PmicLogger: vcgencmd pmic_read_adc unavailable; stopping logger')
                    return
                f.write(f"{time.time()},{' | '.join(raw.strip().splitlines())}\n")
                f.flush()
                time.sleep(self.period_s)

    def __enter__(self):
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()
        return self

    def __exit__(self, *exc):
        self._stop.set()
        self._thread.join(timeout=5)
        print(f'Power telemetry saved to: {self.log_file}')
        return False
