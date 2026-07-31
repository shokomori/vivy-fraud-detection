import os
import subprocess
import time

os.chdir(r'C:\Users\YUKI\Documents\Vivy\vivy_app')
print('cwd', os.getcwd())
print('Launching app on emulator-5554...')
proc = subprocess.Popen([
    r'C:\flutter-sdk\flutter\bin\flutter.bat',
    'run',
    '-d',
    'emulator-5554'
], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
start = time.time()
while time.time() - start < 180:
    line = proc.stdout.readline()
    if not line:
        break
    print(line, end='')
    if 'Running' in line or 'Error' in line or 'Exception' in line:
        break
print('poll', proc.poll())
