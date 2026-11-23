import Base
import ../../compat/nat.bend as Nat

# Bend Engine pure deterministic AI.
#
# The public model separates observations, authored goals, legal actions,
# certified decisions, executable plans, and finite world histories.  Plans are
# aligned with agents by structural position; identity is owned only by Agent,
# so planning and execution never manufacture or rewrite an identifier.
#
# This file contains computation only.  Universally quantified semantic proofs
# live in ai_verification.bend. Every recursion is structurally terminating.

# Types
# =====

type Condition:
  Healthy{}
  Wounded{}

type Goal:
  SurviveGoal{}
  GatherGoal{}
  GuardGoal{}
  ExploreGoal{}

type Memory:
  Memory{
    last_enemy: Bool,
    last_resource: Bool,
    last_danger: Bool,
    observations: Nat
  }

type Agent:
  Agent{
    id: Nat,
    condition: Condition,
    goal: Goal,
    energy: Nat,
    memory: Memory
  }

type Squad:
  SquadEnd{}
  SquadAgent{agent: Agent, tail: Squad}

type Environment:
  Environment{enemy_visible: Bool, resource_visible: Bool, danger: Bool}

type Observation:
  Observation{
    enemy_visible: Bool,
    resource_visible: Bool,
    wounded: Bool,
    danger: Bool
  }

type Action:
  WaitAction{}
  PatrolAction{}
  GatherAction{}
  FleeAction{}
  EngageAction{}

# Decision constructors are legality witnesses by construction.  Constructors
# with a conditional action encode the required observation bit as True{}.
# Arbitrary remaining observation bits stay live data.
type Decision:
  WaitDecision{observation: Observation}
  PatrolDecision{observation: Observation}
  GatherDecision{enemy_visible: Bool, danger: Bool}
  WoundedFleeDecision{
    enemy_visible: Bool,
    resource_visible: Bool,
    danger: Bool
  }
  DangerFleeDecision{enemy_visible: Bool, resource_visible: Bool}
  EngageDecision{resource_visible: Bool, danger: Bool}

type Plan:
  PlanEnd{}
  PlanStep{decision: Decision, tail: Plan}

type AgentTurn:
  AgentTurn{agent: Agent, decision: Decision}

type SquadTurn:
  SquadTurn{agents: Squad, plan: Plan}

type World:
  World{agents: Squad, tick: Nat}

type WorldTurn:
  WorldTurn{world: World, plan: Plan}

type History:
  HistoryEnd{}
  HistoryFrame{environment: Environment, tail: History}

type PlanHistory:
  PlanHistoryEnd{}
  PlanHistoryFrame{plan: Plan, tail: PlanHistory}

type Simulation:
  Simulation{world: World, plans: PlanHistory}

type Utility:
  Utility{
    survival: Nat,
    gathering: Nat,
    defense: Nat,
    exploration: Nat
  }

type Claim<-A: Type, -Property: @-value: A -> Type>:
  Claim{value: A, -proof: Property(value)}

type Verified3<
  -A: Type,
  -First: @-value: A -> Type,
  -Second: @-value: A -> Type,
  -Third: @-value: A -> Type
>:
  Verified3{
    value: A,
    -first: First(value),
    -second: Second(value),
    -third: Third(value)
  }

# Constants
# =========

assert memory_empty_func:
  Memory

def memory_empty_func():
  Memory{False{}, False{}, False{}, 0n}

# Condition-Section
# =================

assert condition_copy:
  forall value: Condition
  Condition & Condition

def condition_copy(value):
  match value:
    case Healthy{}:
      (Healthy{}, Healthy{})
    case Wounded{}:
      (Wounded{}, Wounded{})

assert condition_wounded:
  forall value: Condition
  Bool

def condition_wounded(value):
  match value:
    case Healthy{}:
      False{}
    case Wounded{}:
      True{}

# Goal-Section
# ============

assert goal_copy:
  forall value: Goal
  Goal & Goal

def goal_copy(value):
  match value:
    case SurviveGoal{}:
      (SurviveGoal{}, SurviveGoal{})
    case GatherGoal{}:
      (GatherGoal{}, GatherGoal{})
    case GuardGoal{}:
      (GuardGoal{}, GuardGoal{})
    case ExploreGoal{}:
      (ExploreGoal{}, ExploreGoal{})

# Environment-Section
# ===================

assert environment_copy:
  forall value: Environment
  Environment & Environment

def environment_copy(value):
  match value:
    case Environment{enemy_visible, resource_visible, danger}:
      ((enemy_left, enemy_left_exact), (enemy_right, enemy_right_exact)) = Bool.copy(enemy_visible)
      ((resource_left, resource_left_exact), (resource_right, resource_right_exact)) = Bool.copy(resource_visible)
      ((danger_left, danger_left_exact), (danger_right, danger_right_exact)) = Bool.copy(danger)
      (
        Environment{enemy_left, resource_left, danger_left},
        Environment{enemy_right, resource_right, danger_right}
      )

# Observation-Section
# ===================

assert observation_copy:
  forall value: Observation
  Observation & Observation

def observation_copy(value):
  match value:
    case Observation{enemy_visible, resource_visible, wounded, danger}:
      ((enemy_left, enemy_left_exact), (enemy_right, enemy_right_exact)) = Bool.copy(enemy_visible)
      ((resource_left, resource_left_exact), (resource_right, resource_right_exact)) = Bool.copy(resource_visible)
      ((wounded_left, wounded_left_exact), (wounded_right, wounded_right_exact)) = Bool.copy(wounded)
      ((danger_left, danger_left_exact), (danger_right, danger_right_exact)) = Bool.copy(danger)
      (
        Observation{enemy_left, resource_left, wounded_left, danger_left},
        Observation{enemy_right, resource_right, wounded_right, danger_right}
      )

# Action-Section
# ==============

assert action_copy:
  forall value: Action
  Action & Action

def action_copy(value):
  match value:
    case WaitAction{}:
      (WaitAction{}, WaitAction{})
    case PatrolAction{}:
      (PatrolAction{}, PatrolAction{})
    case GatherAction{}:
      (GatherAction{}, GatherAction{})
    case FleeAction{}:
      (FleeAction{}, FleeAction{})
    case EngageAction{}:
      (EngageAction{}, EngageAction{})

# Decision-Section
# ================

assert decision_observation:
  forall value: Decision
  Observation

def decision_observation(value):
  match value:
    case WaitDecision{observation}:
      observation
    case PatrolDecision{observation}:
      observation
    case GatherDecision{enemy_visible, danger}:
      Observation{enemy_visible, True{}, False{}, danger}
    case WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      Observation{enemy_visible, resource_visible, True{}, danger}
    case DangerFleeDecision{enemy_visible, resource_visible}:
      Observation{enemy_visible, resource_visible, False{}, True{}}
    case EngageDecision{resource_visible, danger}:
      Observation{True{}, resource_visible, False{}, danger}

assert decision_action:
  forall value: Decision
  Action

def decision_action(value):
  match value:
    case WaitDecision{observation}:
      WaitAction{}
    case PatrolDecision{observation}:
      PatrolAction{}
    case GatherDecision{enemy_visible, danger}:
      GatherAction{}
    case WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      FleeAction{}
    case DangerFleeDecision{enemy_visible, resource_visible}:
      FleeAction{}
    case EngageDecision{resource_visible, danger}:
      EngageAction{}

assert decision_copy:
  forall value: Decision
  Decision & Decision

def decision_copy(value):
  match value:
    case WaitDecision{observation}:
      (left, right) = observation_copy(observation)
      (WaitDecision{left}, WaitDecision{right})
    case PatrolDecision{observation}:
      (left, right) = observation_copy(observation)
      (PatrolDecision{left}, PatrolDecision{right})
    case GatherDecision{enemy_visible, danger}:
      ((enemy_left, enemy_left_exact), (enemy_right, enemy_right_exact)) = Bool.copy(enemy_visible)
      ((danger_left, danger_left_exact), (danger_right, danger_right_exact)) = Bool.copy(danger)
      (
        GatherDecision{enemy_left, danger_left},
        GatherDecision{enemy_right, danger_right}
      )
    case WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      ((enemy_left, enemy_left_exact), (enemy_right, enemy_right_exact)) = Bool.copy(enemy_visible)
      ((resource_left, resource_left_exact), (resource_right, resource_right_exact)) = Bool.copy(resource_visible)
      ((danger_left, danger_left_exact), (danger_right, danger_right_exact)) = Bool.copy(danger)
      (
        WoundedFleeDecision{enemy_left, resource_left, danger_left},
        WoundedFleeDecision{enemy_right, resource_right, danger_right}
      )
    case DangerFleeDecision{enemy_visible, resource_visible}:
      ((enemy_left, enemy_left_exact), (enemy_right, enemy_right_exact)) = Bool.copy(enemy_visible)
      ((resource_left, resource_left_exact), (resource_right, resource_right_exact)) = Bool.copy(resource_visible)
      (
        DangerFleeDecision{enemy_left, resource_left},
        DangerFleeDecision{enemy_right, resource_right}
      )
    case EngageDecision{resource_visible, danger}:
      ((resource_left, resource_left_exact), (resource_right, resource_right_exact)) = Bool.copy(resource_visible)
      ((danger_left, danger_left_exact), (danger_right, danger_right_exact)) = Bool.copy(danger)
      (
        EngageDecision{resource_left, danger_left},
        EngageDecision{resource_right, danger_right}
      )

assert decision_is_legal:
  forall value: Decision
  Bool

def decision_is_legal(value):
  match value:
    case WaitDecision{observation}:
      True{}
    case PatrolDecision{observation}:
      True{}
    case GatherDecision{enemy_visible, danger}:
      True{}
    case WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      True{}
    case DangerFleeDecision{enemy_visible, resource_visible}:
      True{}
    case EngageDecision{resource_visible, danger}:
      True{}

# Memory-Section
# ==============

assert memory_observation_count:
  forall value: Memory
  Nat

def memory_observation_count(value):
  match value:
    case Memory{last_enemy, last_resource, last_danger, observations}:
      observations

assert memory_record:
  forall value: Memory
  forall observation: Observation
  Memory

def memory_record(value, observation):
  match value observation:
    case Memory{last_enemy, last_resource, last_danger, observations} Observation{enemy_visible, resource_visible, wounded, danger}:
      Memory{enemy_visible, resource_visible, danger, 1n+observations}

# Agent-Section
# =============

assert agent_id:
  forall value: Agent
  Nat

def agent_id(value):
  match value:
    case Agent{id, condition, goal, energy, memory}:
      id

assert agent_memory_count:
  forall value: Agent
  Nat

def agent_memory_count(value):
  match value:
    case Agent{id, condition, goal, energy, memory}:
      memory_observation_count(memory)

assert agent_perceive:
  forall value: Agent
  forall environment: Environment
  Observation

def agent_perceive(value, environment):
  match value environment:
    case Agent{id, condition, goal, energy, memory} Environment{enemy_visible, resource_visible, danger}:
      Observation{enemy_visible, resource_visible, condition_wounded(condition), danger}

# Squad-Section
# =============

assert squad_count:
  forall value: Squad
  Nat

def squad_count(value):
  match value:
    case SquadEnd{}:
      0n
    case SquadAgent{agent, tail}:
      1n+squad_count(tail)

assert squad_ids:
  forall value: Squad
  List<Nat>

def squad_ids(value):
  match value:
    case SquadEnd{}:
      Nil{}
    case SquadAgent{agent, tail}:
      Con{agent_id(agent), squad_ids(tail)}

# Plan-Section
# ============

assert plan_length:
  forall value: Plan
  Nat

def plan_length(value):
  match value:
    case PlanEnd{}:
      0n
    case PlanStep{decision, tail}:
      1n+plan_length(tail)

assert plan_all_legal:
  forall value: Plan
  Bool

def plan_all_legal(value):
  match value:
    case PlanEnd{}:
      True{}
    case PlanStep{decision, tail}:
      Bool.and(decision_is_legal(decision), plan_all_legal(tail))

assert plan_copy:
  forall value: Plan
  Plan & Plan

def plan_copy(value):
  match value:
    case PlanEnd{}:
      (PlanEnd{}, PlanEnd{})
    case PlanStep{decision, tail}:
      (decision_left, decision_right) = decision_copy(decision)
      (tail_left, tail_right) = plan_copy(tail)
      (
        PlanStep{decision_left, tail_left},
        PlanStep{decision_right, tail_right}
      )

# World-Section
# =============

assert world_agents:
  forall value: World
  Squad

def world_agents(value):
  match value:
    case World{agents, tick}:
      agents

assert world_agent_count:
  forall value: World
  Nat

def world_agent_count(value):
  match value:
    case World{agents, tick}:
      squad_count(agents)

assert world_agent_ids:
  forall value: World
  List<Nat>

def world_agent_ids(value):
  match value:
    case World{agents, tick}:
      squad_ids(agents)

assert world_tick:
  forall value: World
  Nat

def world_tick(value):
  match value:
    case World{agents, tick}:
      tick

# History-Section
# ===============

assert history_length:
  forall value: History
  Nat

def history_length(value):
  match value:
    case HistoryEnd{}:
      0n
    case HistoryFrame{environment, tail}:
      1n+history_length(tail)

# PlanHistory-Section
# ===================

assert plan_history_length:
  forall value: PlanHistory
  Nat

def plan_history_length(value):
  match value:
    case PlanHistoryEnd{}:
      0n
    case PlanHistoryFrame{plan, tail}:
      1n+plan_history_length(tail)

assert plan_history_all_legal:
  forall value: PlanHistory
  Bool

def plan_history_all_legal(value):
  match value:
    case PlanHistoryEnd{}:
      True{}
    case PlanHistoryFrame{plan, tail}:
      Bool.and(plan_all_legal(plan), plan_history_all_legal(tail))

# AgentTurn-Section
# =================

assert agent_turn_agent:
  forall value: AgentTurn
  Agent

def agent_turn_agent(value):
  match value:
    case AgentTurn{agent, decision}:
      agent

assert agent_turn_decision:
  forall value: AgentTurn
  Decision

def agent_turn_decision(value):
  match value:
    case AgentTurn{agent, decision}:
      decision

# SquadTurn-Section
# =================

assert squad_turn_agents:
  forall value: SquadTurn
  Squad

def squad_turn_agents(value):
  match value:
    case SquadTurn{agents, plan}:
      agents

assert squad_turn_plan:
  forall value: SquadTurn
  Plan

def squad_turn_plan(value):
  match value:
    case SquadTurn{agents, plan}:
      plan

# WorldTurn-Section
# =================

assert world_turn_world:
  forall value: WorldTurn
  World

def world_turn_world(value):
  match value:
    case WorldTurn{world, plan}:
      world

assert world_turn_plan:
  forall value: WorldTurn
  Plan

def world_turn_plan(value):
  match value:
    case WorldTurn{world, plan}:
      plan

# Simulation-Section
# ==================

assert simulation_world:
  forall value: Simulation
  World

def simulation_world(value):
  match value:
    case Simulation{world, plans}:
      world

assert simulation_plans:
  forall value: Simulation
  PlanHistory

def simulation_plans(value):
  match value:
    case Simulation{world, plans}:
      plans

# Utility-Section
# ===============

assert utility_for_goal:
  forall value: Utility
  forall goal: Goal
  Nat

def utility_for_goal(value, goal):
  match value goal:
    case Utility{survival, gathering, defense, exploration} SurviveGoal{}:
      survival
    case Utility{survival, gathering, defense, exploration} GatherGoal{}:
      gathering
    case Utility{survival, gathering, defense, exploration} GuardGoal{}:
      defense
    case Utility{survival, gathering, defense, exploration} ExploreGoal{}:
      exploration

# Func-Section
# ============

# Explicit world/action legality model.  Waiting and patrolling are total;
# gathering, fleeing, and engaging expose their environmental hypotheses.
assert gather_is_legal_func:
  forall observation: Observation
  Bool

def gather_is_legal_func(observation):
  match observation:
    case Observation{enemy_visible, resource_visible, wounded, danger}:
      resource_visible

assert flee_is_legal_func:
  forall observation: Observation
  Bool

def flee_is_legal_func(observation):
  match observation:
    case Observation{enemy_visible, resource_visible, wounded, danger}:
      Bool.or(wounded, danger)

assert engage_is_legal_func:
  forall observation: Observation
  Bool

def engage_is_legal_func(observation):
  match observation:
    case Observation{enemy_visible, resource_visible, wounded, danger}:
      enemy_visible

assert action_is_legal_func:
  forall action: Action
  forall observation: Observation
  Bool

def action_is_legal_func(action, observation):
  match action:
    case WaitAction{}:
      True{}
    case PatrolAction{}:
      True{}
    case GatherAction{}:
      gather_is_legal_func(observation)
    case FleeAction{}:
      flee_is_legal_func(observation)
    case EngageAction{}:
      engage_is_legal_func(observation)

# A decision is a constructive certificate connecting its action to the
# observation that permits it.
assert decision_matches_legality_func:
  forall value: Decision
  Bool

def decision_matches_legality_func(value):
  match value:
    case WaitDecision{observation}:
      action_is_legal_func(WaitAction{}, observation)
    case PatrolDecision{observation}:
      action_is_legal_func(PatrolAction{}, observation)
    case GatherDecision{enemy_visible, danger}:
      action_is_legal_func(
        GatherAction{},
        Observation{enemy_visible, True{}, False{}, danger}
      )
    case WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      action_is_legal_func(
        FleeAction{},
        Observation{enemy_visible, resource_visible, True{}, danger}
      )
    case DangerFleeDecision{enemy_visible, resource_visible}:
      action_is_legal_func(
        FleeAction{},
        Observation{enemy_visible, resource_visible, False{}, True{}}
      )
    case EngageDecision{resource_visible, danger}:
      action_is_legal_func(
        EngageAction{},
        Observation{True{}, resource_visible, False{}, danger}
      )

assert perception_from_condition_func:
  forall condition: Condition
  forall environment: Environment
  Observation

def perception_from_condition_func(condition, environment):
  match condition environment:
    case Healthy{} Environment{enemy_visible, resource_visible, danger}:
      Observation{enemy_visible, resource_visible, False{}, danger}
    case Wounded{} Environment{enemy_visible, resource_visible, danger}:
      Observation{enemy_visible, resource_visible, True{}, danger}

# The policy is deterministic and priority ordered: injury and danger precede
# authored goals, then legal goal work, then patrol as a total fallback.
assert planner_survive_func:
  forall wounded: Bool
  forall danger: Bool
  forall enemy_visible: Bool
  forall resource_visible: Bool
  Decision

def planner_survive_func(wounded, danger, enemy_visible, resource_visible):
  match wounded danger:
    case True{} danger_here:
      WoundedFleeDecision{enemy_visible, resource_visible, danger_here}
    case False{} True{}:
      DangerFleeDecision{enemy_visible, resource_visible}
    case False{} False{}:
      PatrolDecision{
        Observation{enemy_visible, resource_visible, False{}, False{}}
      }

assert planner_gather_func:
  forall wounded: Bool
  forall danger: Bool
  forall resource_visible: Bool
  forall enemy_visible: Bool
  Decision

def planner_gather_func(wounded, danger, resource_visible, enemy_visible):
  match wounded danger resource_visible:
    case True{} danger_here resource_here:
      WoundedFleeDecision{enemy_visible, resource_here, danger_here}
    case False{} True{} resource_here:
      DangerFleeDecision{enemy_visible, resource_here}
    case False{} False{} False{}:
      PatrolDecision{Observation{enemy_visible, False{}, False{}, False{}}}
    case False{} False{} True{}:
      GatherDecision{enemy_visible, False{}}

assert planner_guard_func:
  forall wounded: Bool
  forall danger: Bool
  forall enemy_visible: Bool
  forall resource_visible: Bool
  Decision

def planner_guard_func(wounded, danger, enemy_visible, resource_visible):
  match wounded danger enemy_visible:
    case True{} danger_here enemy_here:
      WoundedFleeDecision{enemy_here, resource_visible, danger_here}
    case False{} True{} enemy_here:
      DangerFleeDecision{enemy_here, resource_visible}
    case False{} False{} False{}:
      PatrolDecision{Observation{False{}, resource_visible, False{}, False{}}}
    case False{} False{} True{}:
      EngageDecision{resource_visible, False{}}

assert planner_explore_func:
  forall wounded: Bool
  forall danger: Bool
  forall enemy_visible: Bool
  forall resource_visible: Bool
  Decision

def planner_explore_func(wounded, danger, enemy_visible, resource_visible):
  planner_survive_func(wounded, danger, enemy_visible, resource_visible)

assert planner_decide_func:
  forall goal: Goal
  forall observation: Observation
  Decision

def planner_decide_func(goal, observation):
  match goal:
    case SurviveGoal{}:
      match observation:
        case Observation{enemy_visible, resource_visible, wounded, danger}:
          planner_survive_func(wounded, danger, enemy_visible, resource_visible)
    case GatherGoal{}:
      match observation:
        case Observation{enemy_visible, resource_visible, wounded, danger}:
          planner_gather_func(wounded, danger, resource_visible, enemy_visible)
    case GuardGoal{}:
      match observation:
        case Observation{enemy_visible, resource_visible, wounded, danger}:
          planner_guard_func(wounded, danger, enemy_visible, resource_visible)
    case ExploreGoal{}:
      match observation:
        case Observation{enemy_visible, resource_visible, wounded, danger}:
          planner_explore_func(wounded, danger, enemy_visible, resource_visible)

# Utility is an inspectable explanation of the same priority policy.  Scores
# are not hidden host heuristics: every component is a pure Nat value.
assert planner_survival_utility_func:
  forall wounded: Bool
  forall danger: Bool
  Utility

def planner_survival_utility_func(wounded, danger):
  match wounded danger:
    case True{} danger_here:
      Utility{100n, 0n, 0n, 0n}
    case False{} True{}:
      Utility{100n, 0n, 0n, 0n}
    case False{} False{}:
      Utility{10n, 0n, 0n, 0n}

assert planner_gather_utility_func:
  forall wounded: Bool
  forall danger: Bool
  forall resource_visible: Bool
  Utility

def planner_gather_utility_func(wounded, danger, resource_visible):
  match wounded danger resource_visible:
    case True{} danger_here resource_here:
      Utility{100n, 0n, 0n, 0n}
    case False{} True{} resource_here:
      Utility{100n, 0n, 0n, 0n}
    case False{} False{} False{}:
      Utility{0n, 10n, 0n, 0n}
    case False{} False{} True{}:
      Utility{0n, 80n, 0n, 0n}

assert planner_guard_utility_func:
  forall wounded: Bool
  forall danger: Bool
  forall enemy_visible: Bool
  Utility

def planner_guard_utility_func(wounded, danger, enemy_visible):
  match wounded danger enemy_visible:
    case True{} danger_here enemy_here:
      Utility{100n, 0n, 0n, 0n}
    case False{} True{} enemy_here:
      Utility{100n, 0n, 0n, 0n}
    case False{} False{} False{}:
      Utility{0n, 0n, 10n, 0n}
    case False{} False{} True{}:
      Utility{0n, 0n, 70n, 0n}

assert planner_explore_utility_func:
  forall wounded: Bool
  forall danger: Bool
  Utility

def planner_explore_utility_func(wounded, danger):
  match wounded danger:
    case True{} danger_here:
      Utility{100n, 0n, 0n, 0n}
    case False{} True{}:
      Utility{100n, 0n, 0n, 0n}
    case False{} False{}:
      Utility{0n, 0n, 0n, 10n}

assert planner_utility_func:
  forall goal: Goal
  forall observation: Observation
  Utility

def planner_utility_func(goal, observation):
  match goal:
    case SurviveGoal{}:
      match observation:
        case Observation{enemy_visible, resource_visible, wounded, danger}:
          planner_survival_utility_func(wounded, danger)
    case GatherGoal{}:
      match observation:
        case Observation{enemy_visible, resource_visible, wounded, danger}:
          planner_gather_utility_func(wounded, danger, resource_visible)
    case GuardGoal{}:
      match observation:
        case Observation{enemy_visible, resource_visible, wounded, danger}:
          planner_guard_utility_func(wounded, danger, enemy_visible)
    case ExploreGoal{}:
      match observation:
        case Observation{enemy_visible, resource_visible, wounded, danger}:
          planner_explore_utility_func(wounded, danger)

assert memory_record_decision_func:
  forall value: Memory
  forall decision: Decision
  Memory

def memory_record_decision_func(value, decision):
  memory_record(value, decision_observation(decision))

assert agent_execute_decision_func:
  forall value: Agent
  forall decision: Decision
  Agent

def agent_execute_decision_func(value, decision):
  match value decision:
    case Agent{id, condition, goal, energy, memory} WaitDecision{observation}:
      Agent{id, condition, goal, energy, memory_record(memory, observation)}
    case Agent{id, condition, goal, energy, memory} PatrolDecision{observation}:
      Agent{id, condition, goal, energy, memory_record(memory, observation)}
    case Agent{id, condition, goal, energy, memory} GatherDecision{enemy_visible, danger}:
      Agent{
        id,
        condition,
        goal,
        1n+energy,
        memory_record(memory, Observation{enemy_visible, True{}, False{}, danger})
      }
    case Agent{id, condition, goal, energy, memory} WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      Agent{
        id,
        Healthy{},
        goal,
        energy,
        memory_record(memory, Observation{enemy_visible, resource_visible, True{}, danger})
      }
    case Agent{id, condition, goal, energy, memory} DangerFleeDecision{enemy_visible, resource_visible}:
      Agent{
        id,
        condition,
        goal,
        energy,
        memory_record(memory, Observation{enemy_visible, resource_visible, False{}, True{}})
      }
    case Agent{id, condition, goal, energy, memory} EngageDecision{resource_visible, danger}:
      Agent{
        id,
        condition,
        goal,
        energy,
        memory_record(memory, Observation{True{}, resource_visible, False{}, danger})
      }

assert agent_execute_identity_theorem_func:
  forall value: Agent
  forall decision: Decision
  { agent_id(agent_execute_decision_func(value, decision)) == agent_id(value) : Nat }

def agent_execute_identity_theorem_func(value, decision):
  match value decision:
    case Agent{id, condition, goal, energy, memory} WaitDecision{observation}:
      {==}
    case Agent{id, condition, goal, energy, memory} PatrolDecision{observation}:
      {==}
    case Agent{id, condition, goal, energy, memory} GatherDecision{enemy_visible, danger}:
      {==}
    case Agent{id, condition, goal, energy, memory} WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      {==}
    case Agent{id, condition, goal, energy, memory} DangerFleeDecision{enemy_visible, resource_visible}:
      {==}
    case Agent{id, condition, goal, energy, memory} EngageDecision{resource_visible, danger}:
      {==}

assert agent_turn_finish_claim_func:
  forall id: Nat
  forall condition: Condition
  forall goal: Goal
  forall energy: Nat
  forall memory: Memory
  forall decision: Decision
  Claim<AgentTurn, turn => { agent_id(agent_turn_agent(turn)) == id : Nat }>

def agent_turn_finish_claim_func(id, condition, goal, energy, memory, decision):
  match decision_copy(decision):
    case (decision_execute, decision_plan):
      Claim{
        AgentTurn{
          agent_execute_decision_func(
            Agent{id, condition, goal, energy, memory},
            decision_execute
          ),
          decision_plan
        },
        agent_execute_identity_theorem_func(
          Agent{id, condition, goal, energy, memory},
          decision_execute
        )
      }

assert agent_turn_finish_func:
  forall id: Nat
  forall condition: Condition
  forall goal: Goal
  forall energy: Nat
  forall memory: Memory
  forall decision: Decision
  AgentTurn

def agent_turn_finish_func(id, condition, goal, energy, memory, decision):
  match agent_turn_finish_claim_func(
    id,
    condition,
    goal,
    energy,
    memory,
    decision
  ):
    case Claim{turn, proof}:
      turn

assert agent_turn_func:
  forall value: Agent
  forall environment: Environment
  AgentTurn

def agent_turn_func(value, environment):
  match value:
    case Agent{id, condition, goal, energy, memory}:
      (condition_perception, condition_output) = condition_copy(condition)
      (goal_planner, goal_output) = goal_copy(goal)
      agent_turn_finish_func(
        id,
        condition_output,
        goal_output,
        energy,
        memory,
        planner_decide_func(
          goal_planner,
          perception_from_condition_func(condition_perception, environment)
        ),
      )

assert squad_turn_func:
  forall value: Squad
  forall environment: Environment
  SquadTurn

def squad_turn_func(value, environment):
  match value:
    case SquadEnd{}:
      SquadTurn{SquadEnd{}, PlanEnd{}}
    case SquadAgent{agent, tail}:
      (environment_head, environment_tail) = environment_copy(environment)
      match agent_turn_func(agent, environment_head):
        case AgentTurn{agent_output, decision}:
          match squad_turn_func(tail, environment_tail):
            case SquadTurn{tail_output, tail_plan}:
              SquadTurn{
                SquadAgent{agent_output, tail_output},
                PlanStep{decision, tail_plan}
              }

# Execution accepts any finite plan.  A short plan leaves the remaining squad
# untouched; an overlong plan is ignored after the squad ends.  Verification
# proves identity/count preservation for this stronger, unvalidated domain.
assert decision_intrinsic_legality_theorem_func:
  forall decision: Decision
  { decision_is_legal(decision) == True{} : Bool }

def decision_intrinsic_legality_theorem_func(decision):
  match decision:
    case WaitDecision{observation}:
      {==}
    case PatrolDecision{observation}:
      {==}
    case GatherDecision{enemy_visible, danger}:
      {==}
    case WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      {==}
    case DangerFleeDecision{enemy_visible, resource_visible}:
      {==}
    case EngageDecision{resource_visible, danger}:
      {==}

assert plan_intrinsic_legality_theorem_func:
  forall plan: Plan
  { plan_all_legal(plan) == True{} : Bool }

def plan_intrinsic_legality_theorem_func(plan):
  match plan:
    case PlanEnd{}:
      {==}
    case PlanStep{decision, tail}:
      Equal.trans(
        Bool,
        Bool.and(decision_is_legal(decision), plan_all_legal(tail)),
        plan_all_legal(tail),
        True{},
        Equal.cong(
          Bool,
          Bool,
          legal => Bool.and(legal, plan_all_legal(tail)),
          decision_is_legal(decision),
          True{},
          decision_intrinsic_legality_theorem_func(decision)
        ),
        plan_intrinsic_legality_theorem_func(tail)
      )

assert squad_execute_plan_claim_func:
  forall value: Squad
  forall plan: Plan
  Verified3< Squad, output => {squad_ids(output) == squad_ids(value) : List<Nat>}, output => {squad_count(output) == squad_count(value) : Nat}, output => {plan_all_legal(plan) == True{} : Bool} >

def squad_execute_plan_claim_func(value, plan):
  match value plan:
    case SquadEnd{} PlanEnd{}:
      Verified3{SquadEnd{}, {==}, {==}, {==}}
    case SquadEnd{} PlanStep{decision, plan_tail}:
      Verified3{
        SquadEnd{},
        {==},
        {==},
        plan_intrinsic_legality_theorem_func(
          PlanStep{decision, plan_tail}
        )
      }
    case SquadAgent{agent, tail} PlanEnd{}:
      Verified3{SquadAgent{agent, tail}, {==}, {==}, {==}}
    case SquadAgent{agent, tail} PlanStep{decision, plan_tail}:
      match squad_execute_plan_claim_func(tail, plan_tail):
        case Verified3{tail_output, tail_ids_equal, tail_count_equal, tail_legal}:
          Verified3{
            SquadAgent{
              agent_execute_decision_func(agent, decision),
              tail_output
            },
            Equal.trans(
                List<Nat>,
                Con{
                  agent_id(agent_execute_decision_func(agent, decision)),
                  squad_ids(tail_output)
                },
                Con{agent_id(agent), squad_ids(tail_output)},
                Con{agent_id(agent), squad_ids(tail)},
                Equal.cong(
                  Nat,
                  List<Nat>,
                  id => Con{id, squad_ids(tail_output)},
                  agent_id(agent_execute_decision_func(agent, decision)),
                  agent_id(agent),
                  agent_execute_identity_theorem_func(agent, decision)
                ),
                Equal.cong(
                  List<Nat>,
                  List<Nat>,
                  ids => Con{agent_id(agent), ids},
                  squad_ids(tail_output),
                  squad_ids(tail),
                  tail_ids_equal
                )
              ),
            Equal.cong(
                  Nat,
                  Nat,
                  count => 1n+count,
                  squad_count(tail_output),
                  squad_count(tail),
                  tail_count_equal
                ),
            Equal.trans(
                  Bool,
                  Bool.and(decision_is_legal(decision), plan_all_legal(plan_tail)),
                  plan_all_legal(plan_tail),
                  True{},
                  Equal.cong(
                    Bool,
                    Bool,
                    legal => Bool.and(legal, plan_all_legal(plan_tail)),
                    decision_is_legal(decision),
                    True{},
                    decision_intrinsic_legality_theorem_func(decision)
                  ),
                  tail_legal
                )
          }

assert squad_execute_plan_func:
  forall value: Squad
  forall plan: Plan
  Squad

def squad_execute_plan_func(value, plan):
  match squad_execute_plan_claim_func(value, plan):
    case Verified3{output, ids_equal, count_equal, legal}:
      output

assert world_turn_func:
  forall value: World
  forall environment: Environment
  WorldTurn

def world_turn_func(value, environment):
  match value:
    case World{agents, tick}:
      match squad_turn_func(agents, environment):
        case SquadTurn{agents_output, plan}:
          WorldTurn{World{agents_output, 1n+tick}, plan}

assert world_execute_plan_claim_func:
  forall value: World
  forall plan: Plan
  Verified3< World, output => {world_agent_ids(output) == world_agent_ids(value) : List<Nat>}, output => {world_agent_count(output) == world_agent_count(value) : Nat}, output => {plan_all_legal(plan) == True{} : Bool} >

def world_execute_plan_claim_func(value, plan):
  match value:
    case World{agents, tick}:
      match squad_execute_plan_claim_func(agents, plan):
        case Verified3{agents_output, ids_equal, count_equal, legal}:
          Verified3{World{agents_output, tick}, ids_equal, count_equal, legal}

assert world_execute_plan_func:
  forall value: World
  forall plan: Plan
  World

def world_execute_plan_func(value, plan):
  match world_execute_plan_claim_func(value, plan):
    case Verified3{output, ids_equal, count_equal, legal}:
      output

assert plan_history_legal_combine_theorem_func:
  forall plan: Plan
  forall tail: PlanHistory
  forall plan_legal: {plan_all_legal(plan) == True{} : Bool}
  forall tail_legal: {plan_history_all_legal(tail) == True{} : Bool}
  { plan_history_all_legal(PlanHistoryFrame{plan, tail}) == True{} : Bool }

def plan_history_legal_combine_theorem_func(plan, tail, plan_legal, tail_legal):
  Equal.trans(
    Bool,
    Bool.and(plan_all_legal(plan), plan_history_all_legal(tail)),
    plan_history_all_legal(tail),
    True{},
    Equal.cong(
      Bool,
      Bool,
      legal => Bool.and(legal, plan_history_all_legal(tail)),
      plan_all_legal(plan),
      True{},
      plan_legal
    ),
    tail_legal
  )

assert world_execute_history_claim_func:
  forall history: PlanHistory
  forall value: World
  Verified3< World, output => {world_agent_ids(output) == world_agent_ids(value) : List<Nat>}, output => {world_agent_count(output) == world_agent_count(value) : Nat}, output => {plan_history_all_legal(history) == True{} : Bool} >

def world_execute_history_claim_func(history, value):
  match history:
    case PlanHistoryEnd{}:
      Verified3{value, {==}, {==}, {==}}
    case PlanHistoryFrame{plan, tail}:
      match world_execute_plan_claim_func(value, plan):
        case Verified3{world_step, step_ids, step_count, plan_legal}:
          match world_execute_history_claim_func(tail, world_step):
            case Verified3{world_final, tail_ids, tail_count, tail_legal}:
              Verified3{
                world_final,
                Equal.trans(
                    List<Nat>,
                    world_agent_ids(world_final),
                    world_agent_ids(world_step),
                    world_agent_ids(value),
                    tail_ids,
                    step_ids
                  ),
                Equal.trans(
                      Nat,
                      world_agent_count(world_final),
                      world_agent_count(world_step),
                      world_agent_count(value),
                      tail_count,
                      step_count
                    ),
                plan_history_legal_combine_theorem_func(
                      plan,
                      tail,
                      plan_legal,
                      tail_legal
                    )
              }

assert world_execute_history_func:
  forall history: PlanHistory
  forall value: World
  World

def world_execute_history_func(history, value):
  match world_execute_history_claim_func(history, value):
    case Verified3{output, ids_equal, count_equal, legal}:
      output

assert world_simulate_func:
  forall history: History
  forall value: World
  Simulation

def world_simulate_func(history, value):
  match history:
    case HistoryEnd{}:
      Simulation{value, PlanHistoryEnd{}}
    case HistoryFrame{environment, tail}:
      match world_turn_func(value, environment):
        case WorldTurn{world_output, plan}:
          match world_simulate_func(tail, world_output):
            case Simulation{final_world, tail_plans}:
              Simulation{final_world, PlanHistoryFrame{plan, tail_plans}}

assert plan_valid_for_squad_func:
  forall plan: Plan
  forall squad: Squad
  Bool

def plan_valid_for_squad_func(plan, squad):
  (plan_legal, plan_aligned) = plan_copy(plan)
  Bool.and(
    plan_all_legal(plan_legal),
    Nat.is_eq(plan_length(plan_aligned), squad_count(squad))
  )

assert ai_reference_world_func:
  World

def ai_reference_world_func():
  World{
    SquadAgent{
      Agent{0n, Wounded{}, SurviveGoal{}, 2n, memory_empty_func()},
      SquadAgent{
        Agent{1n, Healthy{}, GatherGoal{}, 0n, memory_empty_func()},
        SquadAgent{
          Agent{2n, Healthy{}, GuardGoal{}, 4n, memory_empty_func()},
          SquadAgent{
            Agent{3n, Healthy{}, ExploreGoal{}, 1n, memory_empty_func()},
            SquadEnd{}
          }
        }
      }
    },
    0n
  }

assert ai_reference_history_func:
  History

def ai_reference_history_func():
  HistoryFrame{
    Environment{True{}, True{}, False{}},
    HistoryFrame{
      Environment{False{}, True{}, True{}},
      HistoryFrame{
        Environment{True{}, False{}, False{}},
        HistoryEnd{}
      }
    }
  }

assert plan_history_check_func:
  forall value: PlanHistory
  forall expected: Nat
  Bool

def plan_history_check_func(value, expected):
  match value expected:
    case PlanHistoryEnd{} 0n:
      True{}
    case PlanHistoryEnd{} 1n+pred:
      False{}
    case PlanHistoryFrame{plan, tail} 0n:
      False{}
    case PlanHistoryFrame{plan, tail} 1n+pred:
      Bool.and(plan_all_legal(plan), plan_history_check_func(tail, pred))

assert ai_reference_check_func:
  Bool

def ai_reference_check_func():
  match world_simulate_func(ai_reference_history_func(), ai_reference_world_func()):
    case Simulation{world, plans}:
      Bool.and(
        Nat.is_eq(world_agent_count(world), 4n),
        plan_history_check_func(plans, 3n)
      )
