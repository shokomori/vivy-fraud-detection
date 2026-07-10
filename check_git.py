import subprocess, re  
files = subprocess.check_output(['git', 'ls-files'], text=True).splitlines()  
