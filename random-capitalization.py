#!/Users/paul/.pyenv/versions/gen-3.6.8/bin/python
# Randomly capitalize a given string
# Python 3.6 or above required.

# String can be given as a parameter with the script. 
# If not given, the user will be asked to provide one by script.

# Requirement
# pip install pyperclip

# Preparation before runniing:
# 1. Update line with correct path
# 2. Activate virtualenv
#
# Example below
# 1) cd pyenv ... >  2) pyenv activate name3.6.8... >  3) pip install pyperclip

# Example output
# >>> ./random-up-low-str.py 'hello world'
#
# Below copied to clipboard:
# Hello WOrLD



from random import choice
import sys

import pyperclip   


check_input = len(sys.argv)
# print(check_input)

if check_input == 1:
    instr = input('Your input: ')
    output = ''.join(choice((str.upper, str.lower))(c) for c in instr)
elif check_input == 2:
    output = ''.join(choice((str.upper, str.lower))(c) for c in sys.argv[1])

print(f"Below copied to clipboard:\n{output}\n")

pyperclip.copy(output)
pyperclip.paste()
