# Research Proposal

## Autonomous Discovery of Optimal Energy Management Strategies for Hybrid AC/DC Microgrids via Agentic AI Experimentation

**Oussama Akir**, PhD Candidate
Sup'Com, Universite de Carthage, Tunisia — COSIM Laboratory
Supervised by Prof. Rim Barrak
Committee: Dr. Fatma Dridi (AI), Dr. Hela (Microgrid Modeling)

Date: March 2026

---

## 1. Problem Statement

### 1.1 Context

Hybrid AC/DC microgrids integrate heterogeneous distributed energy resources (DERs) — photovoltaic arrays, wind turbines, battery storage, fuel cells — with diverse loads and grid-connected operation. The energy management system (EMS) is the supervisory layer that coordinates these resources in real time, balancing power quality, economic efficiency, and component protection.

The design of an effective EMS involves resolving a multi-objective optimization problem across a vast decision space: which fuzzy rules to use, what membership function shapes to adopt, what threshold values to set, how to prioritize battery vs. grid vs. fuel cell dispatch, and how to respond to dynamic tariff signals — all while respecting hard safety constraints imposed by international standards such as IEEE 1547-2018.

### 1.2 The Problem with Current Approaches

Prattico et al. (2025) recently proposed a Mamdani-type fuzzy EMS for a hybrid AC/DC microgrid, demonstrating improvements in power quality (THD_V < 3%, Delta-V within plus/minus 2%) and operating cost reduction (10-15%) compared to an unmanaged baseline. Their work represents the current state of the art in fuzzy EMS design for hybrid microgrids.

However, we identify three fundamental limitations in this approach and in the broader EMS design literature:

**Limitation 1: Manual rule engineering.** The 80 fuzzy rules in Prattico's EMS were designed by human experts using domain knowledge and heuristic reasoning. This manual process cannot guarantee that the resulting rule base is optimal. With 5 membership functions for Delta-P, 4 for SOC, 3 for Tariff, and 4 output variables, the theoretical decision space contains thousands of possible rule-output combinations. No human can systematically explore this space.

**Limitation 2: No formal safety guarantees.** The fuzzy EMS produces "soft" control signals — continuous values that influence battery charge/discharge, grid exchange, and fuel cell activation. There is no formal mechanism to guarantee that the resulting system state will always satisfy the hard constraints of IEEE 1547-2018 (voltage within plus/minus 10%, frequency within plus/minus 0.2 Hz). The EMS operates reactively: it observes the current state and responds. It does not anticipate violations.

**Limitation 3: Single-scenario validation.** The EMS is designed and tuned for a specific set of operating conditions (Reggio Calabria, June, one representative day). There is no systematic exploration of how the EMS performs under parameter variations, unexpected weather patterns, or component degradation. The robustness analysis in the paper (Section 4.10) uses Monte Carlo simulation, but the EMS design itself is not informed by these results.

### 1.3 The Gap

The central gap we address is:

> Current EMS design for hybrid microgrids relies on manual human expertise to navigate a vast decision space, producing solutions that are neither provably optimal nor formally safe. The design process is slow (weeks of expert time), non-reproducible (different experts produce different designs), and unable to discover counter-intuitive strategies that might outperform human intuition.

---

## 2. Proposed Approach

### 2.1 Core Idea

We propose to replace manual EMS design with **autonomous AI-driven experimentation**. An AI agent — powered by a large language model (LLM) — reads the EMS source code, forms hypotheses about potential improvements, modifies the code, executes the simulation on a validated physical plant model, evaluates the results against multi-objective criteria, and decides whether to keep or discard each modification. This process repeats autonomously, producing hundreds of validated EMS configurations overnight.

This approach is inspired by Karpathy's AutoResearch framework (March 2026), which demonstrated that an AI agent can autonomously conduct 700 machine learning experiments in 2 days, discovering improvements that transfer to larger models. We extend this paradigm from ML training to physical system simulation — a domain where it has never been applied.

### 2.2 Why This Is Different from Existing Optimization

| Approach | What it does | What it cannot do |
|----------|-------------|-------------------|
| Genetic Algorithm (GA/PSO) | Explores a fixed parameter space using evolutionary operators | Cannot modify code structure, add/remove rules, or explain why a change works |
| Bayesian Optimization | Efficiently navigates parameter spaces using surrogate models | Fixed search space, no architectural changes, no hypothesis formation |
| Reinforcement Learning | Learns a policy through interaction with environment | Black-box output, no interpretability, requires extensive training |
| AutoML | Automates model selection and hyperparameter tuning | Limited to ML models, not applicable to physical simulation code |
| **Our approach** | LLM agent reads simulation code, forms hypotheses, modifies architecture and parameters, evaluates on physical plant | Requires a validated simulation plant and well-defined evaluation metrics |

The fundamental difference is that our agent operates at the **code level**, not the **parameter level**. It can:
- Add or remove fuzzy rules (architectural change)
- Reshape membership functions (structural change)
- Modify control logic (algorithmic change)
- Adjust numerical parameters (parametric change)
- Combine changes from different experiments (compositional discovery)

This is agentic scientific experimentation, not parameter tuning.

### 2.3 Architecture

```
+------------------------------------------------------------------+
|                    AUTORESEARCH AGENT (LLM)                       |
|                                                                    |
|  1. READ current EMS code (create_prattico_fis.m, etc.)           |
|  2. ANALYZE previous experiment results                            |
|  3. FORM HYPOTHESIS ("adding a rule for deficit+medium SOC        |
|     with high tariff might reduce grid import during peak")        |
|  4. MODIFY code (add rule, change MF, adjust parameter)           |
|  5. EXECUTE simulation (build_fullday → sim 24s → evaluate)       |
|  6. EVALUATE against multi-objective criteria                      |
|  7. DECIDE: keep (improvement) or discard (regression)             |
|  8. LOG: hypothesis, modification, result, decision                |
|  9. REPEAT                                                         |
+------------------------------------------------------------------+
          |                    |                    |
          v                    v                    v
+------------------+  +-----------------+  +------------------+
| SIMSCAPE PLANT   |  | EVALUATION      |  | SAFETY           |
| (Validated)      |  | METRICS         |  | CONSTRAINTS      |
|                  |  |                 |  |                  |
| PV 150kWp        |  | Delta-V (%)     |  | Vdc: 712.5-787.5V|
| Battery 200kWh   |  | SOC range (%)   |  | SOC: 30-90%      |
| WT 60kW          |  | Daily cost (EUR) |  | FC activations   |
| FC 20kW          |  | Self-consumption |  | IEEE 1547 Cat II |
| Loads (DC+AC)    |  | Battery DoD     |  | Trip thresholds  |
| VSC 150kVA       |  | Grid imports    |  |                  |
+------------------+  +-----------------+  +------------------+
```

### 2.4 Safety as a Hard Constraint

Unlike pure optimization approaches, our framework enforces **hard safety constraints** at the evaluation stage. An experiment is automatically rejected if any of the following conditions is violated during simulation:

| Constraint | Threshold | Source |
|-----------|-----------|--------|
| DC bus voltage | 712.5 V < V_dc < 787.5 V | IEEE 1547-2018, Table 11 (plus/minus 5%) |
| Battery SOC | 30% < SOC < 90% | Prattico EMS operational limits |
| Frequency (when AC modeled) | 49.8 Hz < f < 50.2 Hz | ENTSO-E normal operation |
| THD_V (when AC modeled) | THD_V < 5% | IEEE 519-2022 |
| FC thermal stress | Max N activations per day | IEC 62282-3-100 |

This means the agent can only discover EMS configurations that are **safe by construction**. Every experiment that passes evaluation is guaranteed to satisfy IEEE 1547 compliance. This is where the Control Barrier Function (CBF) concept enters — not as the primary contribution, but as the mathematical framework for defining and enforcing safety barriers within the autonomous experimentation loop.

---

## 3. Research Questions

We pose three research questions:

**RQ1:** Can an AI agent autonomously discover EMS configurations that outperform manually-designed fuzzy rules (Prattico et al. 2025) in terms of voltage stability, battery lifetime, and economic efficiency?

**RQ2:** How many autonomous experiments are needed to discover significant improvements, and what types of modifications (parametric, structural, architectural) contribute most to performance gains?

**RQ3:** Do the improvements discovered by the agent on one scenario (e.g., June in Reggio Calabria) generalize to unseen conditions (e.g., December, different load profiles, component degradation)?

---

## 4. Methodology

### 4.1 Phase 1 — Validated Simulation Plant (Completed)

We have reproduced the hybrid AC/DC microgrid described in Prattico et al. (2025) using MATLAB/Simulink Simscape Electrical. The plant includes:

- Photovoltaic system (150 kWp, single-diode model, Eq. 8-9)
- Battery energy storage (200 kWh, Rint model, bidirectional buck-boost, Eq. 17-18)
- Wind turbine (60 kW, aerodynamic model, Eq. 10-11)
- PEMFC fuel cell (20 kW, Nernst equation, Eq. 15-16)
- DC bus (750 V), DC and AC loads (110 kW peak combined)
- VSC interface (150 kVA)
- Power quality monitoring (Delta-V)
- Baseline fuzzy EMS (Mamdani, 60 rules)

The model has been validated through 84 automated integration tests across 7 phases (B through H), plus 7 standalone FIS validation tests against Table 3 of the reference paper, and 15 full-day (24h) profile validation tests. Total: 106/106 tests pass.

Environmental data uses PVGIS JRC satellite irradiance for Reggio Calabria (38.11N, 15.65E), wind speed corrected to hub height (IEC 61400-1), ARERA electricity tariffs (F1/F2/F3 bands), and calibrated load profiles based on Prattico Figure 10 with day-to-day variability.

### 4.2 Phase 2 — AutoResearch Agent Adaptation

We adapt Karpathy's AutoResearch framework (630-line Python script, MIT license) for physical simulation:

**Modification 1: Compute budget.** Original AutoResearch uses 5-minute GPU training runs. Our Simscape full-day simulation completes in 3 seconds. This means we can run approximately 1,200 experiments per hour — an order of magnitude more than ML training.

**Modification 2: Evaluation metrics.** Original AutoResearch evaluates a single metric (training loss). We define a multi-objective evaluation function:

```
Score = w1 * (1 - DeltaV_norm)          # voltage stability
      + w2 * (1 - DoD_norm)             # battery lifetime
      + w3 * (1 - cost_norm)            # economic efficiency
      + w4 * self_consumption_norm       # renewable utilization
      - penalty * safety_violations      # hard constraint (large penalty)
```

where the weights w1-w4 reflect engineering priorities and can themselves be explored by the agent.

**Modification 3: Code modification scope.** The agent is authorized to modify only specific files:
- `create_prattico_fis.m` — fuzzy rules and membership functions
- `build_ems_fuzzy.m` — EMS control logic and thresholds
- Selected parameters in `build_fullday.m` — component sizing within realistic bounds

All physical plant code (`build_pv_system.m`, `build_battery_system.m`, etc.) is read-only. The agent can optimize the EMS but cannot change the physics.

**Modification 4: Hypothesis logging.** Each experiment is logged with:
- Natural language hypothesis (what the agent expects to happen)
- Code diff (exactly what was changed)
- Simulation results (all metrics)
- Decision (keep/discard) with reasoning
- Cumulative improvement trajectory

This log constitutes a **machine-generated research notebook** — an artifact of independent scientific interest.

### 4.3 Phase 3 — Experimentation Campaigns

We plan three campaigns:

**Campaign A: Parametric discovery (500 experiments)**
The agent explores numerical parameters: MF vertices, PI gains, activation thresholds, SOC limits. This establishes a parametrically-optimal baseline.

**Campaign B: Structural discovery (500 experiments)**
The agent explores rule modifications: adding rules, removing rules, changing consequents, reshaping membership functions. This discovers novel EMS architectures.

**Campaign C: Compositional discovery (200 experiments)**
Starting from the best results of Campaigns A and B, the agent combines discoveries to find synergistic improvements.

### 4.4 Phase 4 — Validation and Generalization

Discovered configurations are validated through:

1. **Cross-scenario testing:** Run the discovered EMS on 12 representative months (TMY from PVGIS), not just June.
2. **Robustness analysis:** Monte Carlo simulation with plus/minus 10% parameter variation (following Prattico Section 4.10 methodology).
3. **Comparison:** Case A (no EMS) vs. Case B (Prattico manual EMS) vs. Case C (agent-discovered EMS), reporting all metrics from the reference paper's Table 7.
4. **Interpretability analysis:** Extract and document the most impactful rules/parameters discovered by the agent. Are the agent's discoveries interpretable by human experts?

---

## 5. Expected Contributions

### Contribution 1: Methodological (primary)
First application of autonomous AI experimentation (AutoResearch paradigm) to physical system simulation and power systems design. We demonstrate that an LLM agent can conduct hypothesis-driven scientific experimentation on a validated Simscape plant, discovering EMS configurations that outperform manual expert design.

### Contribution 2: Technical
An optimized EMS configuration for hybrid AC/DC microgrids that improves upon Prattico et al. (2025) in at least two of: voltage stability, battery lifetime, economic efficiency, and renewable self-consumption — while maintaining strict IEEE 1547-2018 Category II compliance.

### Contribution 3: Safety framework
Integration of formal safety constraints (derived from IEEE 1547 and IEC standards) as hard barriers within the autonomous experimentation loop, ensuring that every discovered configuration is safe by construction.

### Contribution 4: Reproducibility
A fully open-source experimental framework (AutoResearch script + Simscape plant + evaluation metrics + experiment logs) that enables any researcher to reproduce our results or apply the methodology to their own microgrid configurations.

---

## 6. Relationship to Prior Work

### 6.1 Building on Prattico et al. (2025)
Our work uses Prattico's microgrid architecture and fuzzy EMS as the validated baseline. We do not claim that their EMS is flawed — we claim that the manual design process that produced it cannot guarantee optimality, and that an autonomous agent can systematically explore the design space to find improvements.

### 6.2 Building on Karpathy (2026)
AutoResearch demonstrated the viability of autonomous AI experimentation for ML training. We extend the paradigm to a fundamentally different domain: physical system simulation with safety constraints. This extension is non-trivial because physical simulations have hard constraints (voltage limits, thermal limits) that ML training does not.

### 6.3 Positioning relative to Safe RL literature
Recent work on Safe RL for microgrids (Oak Ridge National Laboratory 2025, Physics-shielded DRL 2025) uses end-to-end deep reinforcement learning with safety constraints. Our approach differs architecturally: we retain an interpretable EMS (fuzzy rules) and use the AI agent for design-time optimization, not runtime control. This means:
- The discovered EMS is interpretable (human-readable rules)
- The discovered EMS is lightweight (5-10 microseconds per inference)
- The discovered EMS can be deployed on embedded hardware (DSP, FPGA)
- Safety is guaranteed at design time, not just runtime

---

## 7. Limitations and Risks

| Limitation | Impact | Mitigation |
|-----------|--------|------------|
| LLM agent quality depends on the model used | Different LLMs may produce different results | Report results for multiple LLMs (Claude, GPT-4, DeepSeek) |
| 3-second simulation uses average-value models | Detailed switching dynamics not captured | Validate top-3 discoveries on full physical model (MaxStep=3 microseconds) |
| AC bus not physically modeled | Cannot evaluate THD_V, TDD, Delta-f directly | Report DC-side metrics; AC validation as future work |
| Agent modifications are stochastic | Non-deterministic experimental log | Use fixed random seeds; report variance across 3 independent runs |
| The Simscape plant is itself a simulation | Results not validated on hardware | HIL validation on Speedgoat as future work (Phase 5) |

---

## 8. Timeline

| Period | Milestone | Deliverable |
|--------|-----------|-------------|
| March 2026 (completed) | Simscape plant validated | 106/106 tests, 26-slide presentation |
| April 1-7 | AutoResearch agent adapted for MATLAB/Simscape | Working prototype, first 50 experiments |
| April 8-14 | Campaign A: parametric discovery (500 experiments) | Parametrically-optimal baseline |
| April 15-21 | Campaign B: structural discovery (500 experiments) | Novel EMS architectures |
| April 22-30 | Validation, generalization, comparison (Case A/B/C) | Complete results table |
| May 1-15 | Paper draft | Full manuscript submitted for committee review |
| May 15-31 | Revisions based on committee feedback | Final manuscript |
| June 2026 | Submission to target journal | Paper under review |

---

## 9. Target Venues

| Journal | IF | Why |
|---------|-----|-----|
| Applied Energy (Elsevier) | 11.2 | Physical modeling + AI optimization + energy systems |
| IEEE Transactions on Smart Grid | 9.6 | Smart grid + autonomous control + standards compliance |
| Energies (MDPI) | 3.2 | Same journal as Prattico (direct extension), fast review |
| Nature Energy | 67.4 | If results are transformative (unlikely but worth considering) |

Recommended primary target: **Applied Energy** (high impact, accepts methodology papers, strong in energy AI).
Fallback: **Energies MDPI** (fast turnaround, same community as Prattico).

---

## 10. Conclusion

This proposal presents a paradigm shift in EMS design for hybrid microgrids: from manual expert engineering to autonomous AI-driven scientific experimentation. By combining a validated physical simulation plant (Prattico reproduction in Simscape) with the AutoResearch autonomous experimentation framework (Karpathy 2026), we create a system where an AI agent conducts hundreds of hypothesis-driven experiments overnight, discovering safe, optimal, and interpretable EMS configurations that human designers cannot find manually.

The timing is critical: AutoResearch was released on March 8, 2026. To our knowledge, no published work has applied autonomous AI experimentation to power systems or physical simulation of any kind. We have a first-mover opportunity that aligns with the growing interest in agentic AI (2026) and the urgent need for better microgrid management in the face of increasing renewable penetration.

---

## References

1. Prattico, D. et al. (2025). "Enhancing Power Quality and Reducing Costs in Hybrid AC/DC Microgrids via Fuzzy EMS." Energies, 18(22), 5985. DOI: 10.3390/en18225985

2. Karpathy, A. (2026). "autoresearch: AI agents running research on single-GPU nanochat training automatically." GitHub. https://github.com/karpathy/autoresearch

3. IEEE Std 1547-2018. "Standard for Interconnection and Interoperability of Distributed Energy Resources with Associated Electric Power Systems Interfaces."

4. IEEE Std 519-2022. "Standard for Harmonic Control in Electric Power Systems."

5. IEC 62898-1:2017. "Microgrids — Part 1: Guidelines for microgrid projects planning and specification."

6. Safe Deep RL for Microgrid Restoration. Oak Ridge National Laboratory / IEEE Trans. Industry Applications, 2025.

7. Physics-shielded DRL for Microgrid EMS. ScienceDirect, 2025.

8. Critical Review of Safe RL in Power/Energy Systems. Engineering Applications of AI, 2025.

9. PVGIS. EU Joint Research Centre. Photovoltaic Geographical Information System.

10. ARERA Delibera 654/2023/R/EEL. Italian Energy Regulatory Authority tariff structure.
