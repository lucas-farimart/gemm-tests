
BUILD_DIR  = xcelium.d
WAVE_DIR   = waves
XRUN       = xrun
XRUN_FLAGS = -sv -64 -access +rwc -timescale 1ns/1ns
WAVE_FLAGS = -input waves.tcl # ainda nao existe 

# Alvo padrao
all: help
.PHONY: all help only_srams sram_dclb clean

#========================================================
#                 COMANDOS DE SIMULACAO
#========================================================
help:
	@echo "" 
	@echo "Testes de Arquiteturas para Multipicação Matriz-Vetor"
	@echo "" 
	@echo "|-----------------------------------|" 
	@echo "| TESTE             | COMANDO MAKE  |"
	@echo "|-------------------|---------------|"
	@echo "| Duas Mems SRAM    | only_srams    |"
	@echo "| SRAM + DCLB       | sram_dclb     |"
	@echo "|-----------------------------------|"
	@echo "" 

only_srams:
	clear
	@cd only_srams
	@echo "Running simulation with only SRAMs (GUI)..."
	$(XRUN) $(XRUN_FLAGS) -f only_srams/rtl.lst \
	-top tb_only_srams -gui 

gpt:
	clear
	@cd only_srams
	@echo "Running simulation with only SRAMs (GPT)..."
	$(XRUN) $(XRUN_FLAGS) -f only_srams/rtl.lst \
	-top tb_only_gpt -gui 

sram_dclb:
	clear
	@cd sram_dclb
	@echo "Running simulation with SRAM + DCLB (GUI)..."
	$(XRUN) $(XRUN_FLAGS) -f sram_dclb/rtl.lst \
	-top tb_sram_dclb -gui 