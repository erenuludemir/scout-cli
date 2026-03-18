# Orchestrator

This directory will hold orchestration definitions for multiple AI component services (QuantumAI, QuantumTechnoAI, Mechanics, DecisionAI, ElectronAI, CommunicationAI, SignalsAI, SelfAgentTrainerAI, ReleaseAI, ProductionAI, StockAI, TransferAI, DebugAI, ManagerAI, ModulesAI, BootAI, ExecuteAI/SupervizorAI).

## Planned structure (incremental)

- components/<name>/Dockerfile
- components/<name>/app/ (service code or model server)
- supervisor/ (ExecuteAI runtime controller scripts)

## Roadmap

1. Repair base docker-compose YAML formatting corruption (DONE).
2. Introduce modular compose fragments under orchestrator/components.
3. Add a generation script to materialize combined compose from fragments.
4. Implement Supervisor (SupervizorAI.sh) to manage lifecycle, health, and rolling restarts.
5. Add local model registry / fine-tune harness ("locally trained AI").

This README is a placeholder until components are implemented.
