setup:
	ansible-playbook --ask-become-pass setup.yml --extra-vars "@vars.yml"

