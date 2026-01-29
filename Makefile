# ============================================================================
# Vivado Makefile — AD4134 (2023.1)
# ============================================================================

VIVADO      ?= vivado
SCRIPT      := scripts/tq15eg_project.tcl
LOG         := vivado.log
JOURNAL     := vivado.jou

.PHONY: all project clean help

all: project

project:
	$(VIVADO) -mode batch \
	          -source $(SCRIPT) \
	          -log $(LOG) \
	          -journal $(JOURNAL)

clean:
	rm -rf vivado_2023_1 *.log *.jou *.str

help:
	@echo "Targets:"
	@echo "  make        - Create Vivado project"
	@echo "  make clean  - Remove generated files"
	@echo "  make help   - Show this help"
