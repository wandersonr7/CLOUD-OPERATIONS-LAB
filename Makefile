# Shortcuts for chaos/lab.sh (Linux, macOS, CI).
# On Windows, run the script directly from Git Bash: bash chaos/lab.sh drill 04

LAB := bash chaos/lab.sh
IDS := 01 02 03 04 05 06 07 08 09

.PHONY: up verify list down drill-all $(addprefix break-,$(IDS)) $(addprefix detect-,$(IDS)) $(addprefix fix-,$(IDS)) $(addprefix drill-,$(IDS))

up:
	$(LAB) up

verify:
	$(LAB) verify

list:
	$(LAB) list

down:
	docker compose down
	docker rm -f lab-dependency 2>/dev/null || true

break-%:
	$(LAB) break $*

detect-%:
	$(LAB) detect $*

fix-%:
	$(LAB) fix $*

drill-%:
	$(LAB) drill $*

drill-all:
	@for id in $(IDS); do $(LAB) drill $$id || exit 1; done
