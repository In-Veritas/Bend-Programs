import Base
import ./ai.bend as AI

# Mathematical verification for Bend Engine AI.
#
# Every Assert below is universally quantified over its visible inputs.  The
# recursive assertions are structural inductions over arbitrary squads, plans,
# and finite histories.  No closed scenario is called a proof.

# Types
# =====

type VerificationAudit:
  VerificationAudit{
    -decision_legality:
      @decision: AI.Decision -> {
        AI.decision_matches_legality_func(decision) == True{} : Bool
      },
    -planner_legality:
      @goal: AI.Goal -> @observation: AI.Observation -> {
        AI.decision_matches_legality_func(
          AI.planner_decide_func(goal, observation)
        ) == True{} : Bool
      },
    -planner_determinism:
      @left_goal: AI.Goal -> @right_goal: AI.Goal ->
      @left_observation: AI.Observation -> @right_observation: AI.Observation ->
      @goal_equal: {left_goal == right_goal : AI.Goal} ->
      @observation_equal: {
        left_observation == right_observation : AI.Observation
      } -> {
        AI.planner_decide_func(left_goal, left_observation)
        == AI.planner_decide_func(right_goal, right_observation)
        : AI.Decision
      },
    -agent_execution:
      @agent: AI.Agent -> @decision: AI.Decision -> ({
        AI.agent_id(AI.agent_execute_decision_func(agent, decision))
        == AI.agent_id(agent) : Nat
      } & {
        AI.agent_memory_count(AI.agent_execute_decision_func(agent, decision))
        == 1n+AI.agent_memory_count(agent) : Nat
      }),
    -arbitrary_plan_execution:
      @world: AI.World -> @plan: AI.Plan -> AI.Verified3<
        AI.World,
        output => {
          AI.world_agent_ids(output) == AI.world_agent_ids(world) : List<Nat>
        },
        output => {
          AI.world_agent_count(output) == AI.world_agent_count(world) : Nat
        },
        output => {AI.plan_all_legal(plan) == True{} : Bool}
      >,
    -generated_plan_execution:
      @world: AI.World -> @goal: AI.Goal -> @observation: AI.Observation ->
        AI.Verified3<
          AI.World,
          output => {
            AI.world_agent_ids(output) == AI.world_agent_ids(world) : List<Nat>
          },
          output => {
            AI.world_agent_count(output) == AI.world_agent_count(world) : Nat
          },
          output => {
            AI.plan_all_legal(
              AI.PlanStep{
                AI.planner_decide_func(goal, observation),
                AI.PlanEnd{}
              }
            ) == True{} : Bool
          }
        >,
    -finite_history:
      @history: AI.PlanHistory -> @world: AI.World -> AI.Verified3<
        AI.World,
        output => {
          AI.world_agent_ids(output) == AI.world_agent_ids(world) : List<Nat>
        },
        output => {
          AI.world_agent_count(output) == AI.world_agent_count(world) : Nat
        },
        output => {AI.plan_history_all_legal(history) == True{} : Bool}
      >,
    -replay_determinism:
      @left_history: AI.History -> @right_history: AI.History ->
      @left_world: AI.World -> @right_world: AI.World ->
      @history_equal: {left_history == right_history : AI.History} ->
      @world_equal: {left_world == right_world : AI.World} -> {
        AI.world_simulate_func(left_history, left_world)
        == AI.world_simulate_func(right_history, right_world)
        : AI.Simulation
      },
    semantic_claims: U32,
    helper_lemmas: U32,
    closed_certificates: U32
  }

# Constants
# =========

# DecisionLegalityClaim-Section
# ============================

# A semantic claim about the explicit Observation x Action legality relation.
assert DecisionLegalityClaim_func:
  forall -decision: AI.Decision
  Type

def DecisionLegalityClaim_func(decision):
  {
    AI.decision_matches_legality_func(decision) == True{}
    : Bool
  }

# Proof by the constructive Decision representation: each conditional action
# constructor carries the observation fact that makes it legal.
assert DecisionLegalityAssert_func:
  forall decision: AI.Decision
  DecisionLegalityClaim_func(decision)

def DecisionLegalityAssert_func(decision):
  match decision:
    case AI.WaitDecision{observation}:
      {==}
    case AI.PatrolDecision{observation}:
      {==}
    case AI.GatherDecision{enemy_visible, danger}:
      {==}
    case AI.WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      {==}
    case AI.DangerFleeDecision{enemy_visible, resource_visible}:
      {==}
    case AI.EngageDecision{resource_visible, danger}:
      {==}

# PlannerLegalityClaim-Section
# ===========================

assert PlannerLegalityClaim_func:
  forall -goal: AI.Goal
  forall -observation: AI.Observation
  Type

def PlannerLegalityClaim_func(goal, observation):
  DecisionLegalityClaim_func(AI.planner_decide_func(goal, observation))

# The planner's codomain is Decision rather than raw Action, so total planning
# constructs the legality witness instead of checking legality after the fact.
assert PlannerLegalityAssert_func:
  forall goal: AI.Goal
  forall observation: AI.Observation
  PlannerLegalityClaim_func(goal, observation)

def PlannerLegalityAssert_func(goal, observation):
  DecisionLegalityAssert_func(AI.planner_decide_func(goal, observation))

# PlannerDeterminismClaim-Section
# ==============================

# Explicit hypotheses: identical goals and perceptions produce identical
# decisions.  This is functional determinism, not a repeated-run test.
assert PlannerDeterminismClaim_func:
  forall -left_goal: AI.Goal
  forall -right_goal: AI.Goal
  forall -left_observation: AI.Observation
  forall -right_observation: AI.Observation
  Type

def PlannerDeterminismClaim_func(left_goal, right_goal, left_observation, right_observation):
  {
    AI.planner_decide_func(left_goal, left_observation)
    == AI.planner_decide_func(right_goal, right_observation)
    : AI.Decision
  }

assert PlannerDeterminismAssert_func:
  forall left_goal: AI.Goal
  forall right_goal: AI.Goal
  forall left_observation: AI.Observation
  forall right_observation: AI.Observation
  forall goal_equal: {left_goal == right_goal : AI.Goal}
  forall observation_equal: { left_observation == right_observation : AI.Observation }
  PlannerDeterminismClaim_func( left_goal, right_goal, left_observation, right_observation )

def PlannerDeterminismAssert_func(left_goal, right_goal, left_observation, right_observation, goal_equal, observation_equal):
  Equal.trans(
    AI.Decision,
    AI.planner_decide_func(left_goal, left_observation),
    AI.planner_decide_func(right_goal, left_observation),
    AI.planner_decide_func(right_goal, right_observation),
    Equal.cong(
      AI.Goal,
      AI.Decision,
      goal => AI.planner_decide_func(goal, left_observation),
      left_goal,
      right_goal,
      goal_equal
    ),
    Equal.cong(
      AI.Observation,
      AI.Decision,
      observation => AI.planner_decide_func(right_goal, observation),
      left_observation,
      right_observation,
      observation_equal
    )
  )

# AgentExecutionClaim-Section
# ===========================

assert memory_record_increment_theorem_func:
  forall memory: AI.Memory
  forall observation: AI.Observation
  { AI.memory_observation_count(AI.memory_record(memory, observation)) == 1n+AI.memory_observation_count(memory) : Nat }

def memory_record_increment_theorem_func(memory, observation):
  match memory observation:
    case AI.Memory{last_enemy, last_resource, last_danger, observations} AI.Observation{enemy_visible, resource_visible, wounded, danger}:
      {==}

assert AgentExecutionClaim_func:
  forall -agent: AI.Agent
  forall -decision: AI.Decision
  Type

def AgentExecutionClaim_func(agent, decision):
  {
    AI.agent_id(AI.agent_execute_decision_func(agent, decision))
    == AI.agent_id(agent)
    : Nat
  } & {
    AI.agent_memory_count(AI.agent_execute_decision_func(agent, decision))
    == 1n+AI.agent_memory_count(agent)
    : Nat
  }

# Arbitrary decisions can alter condition, energy, and memory contents, but
# they cannot alter identity and record exactly one new perception.
assert AgentExecutionAssert_func:
  forall agent: AI.Agent
  forall decision: AI.Decision
  AgentExecutionClaim_func(agent, decision)

def AgentExecutionAssert_func(agent, decision):
  match agent decision:
    case AI.Agent{id, condition, goal, energy, memory} AI.WaitDecision{observation}:
      ({==}, memory_record_increment_theorem_func(memory, observation))
    case AI.Agent{id, condition, goal, energy, memory} AI.PatrolDecision{observation}:
      ({==}, memory_record_increment_theorem_func(memory, observation))
    case AI.Agent{id, condition, goal, energy, memory} AI.GatherDecision{enemy_visible, danger}:
      (
        {==},
        memory_record_increment_theorem_func(
          memory,
          AI.Observation{enemy_visible, True{}, False{}, danger}
        )
      )
    case AI.Agent{id, condition, goal, energy, memory} AI.WoundedFleeDecision{enemy_visible, resource_visible, danger}:
      (
        {==},
        memory_record_increment_theorem_func(
          memory,
          AI.Observation{enemy_visible, resource_visible, True{}, danger}
        )
      )
    case AI.Agent{id, condition, goal, energy, memory} AI.DangerFleeDecision{enemy_visible, resource_visible}:
      (
        {==},
        memory_record_increment_theorem_func(
          memory,
          AI.Observation{enemy_visible, resource_visible, False{}, True{}}
        )
      )
    case AI.Agent{id, condition, goal, energy, memory} AI.EngageDecision{resource_visible, danger}:
      (
        {==},
        memory_record_increment_theorem_func(
          memory,
          AI.Observation{True{}, resource_visible, False{}, danger}
        )
      )

# Func-Section
# ============

# Plan execution is verified by the proof-carrying AI.Verified3 core.

# PlanExecutionInvariantClaim-Section
# ===================================

# Stronger than a validated-plan theorem: every arbitrary finite plan preserves
# actual world IDs and actual agent count.  Therefore every generated or
# externally validated plan does too.
assert PlanExecutionInvariantClaim_func:
  forall -world: AI.World
  forall -plan: AI.Plan
  Type

def PlanExecutionInvariantClaim_func(world, plan):
  AI.Verified3<
    AI.World,
    output => {
      AI.world_agent_ids(output) == AI.world_agent_ids(world) : List<Nat>
    },
    output => {
      AI.world_agent_count(output) == AI.world_agent_count(world) : Nat
    },
    output => {AI.plan_all_legal(plan) == True{} : Bool}
  >

assert PlanExecutionInvariantAssert_func:
  forall world: AI.World
  forall plan: AI.Plan
  PlanExecutionInvariantClaim_func(world, plan)

def PlanExecutionInvariantAssert_func(world, plan):
  AI.world_execute_plan_claim_func(world, plan)

# GeneratedPlanExecutionClaim-Section
# ===================================

# End-to-end composition: for every world, goal, and observation, execute the
# plan produced by the planner and return the same combined ID/count/legality
# certificate as arbitrary validated execution.
assert GeneratedPlanExecutionClaim_func:
  forall -world: AI.World
  forall -goal: AI.Goal
  forall -observation: AI.Observation
  Type

def GeneratedPlanExecutionClaim_func(world, goal, observation):
  PlanExecutionInvariantClaim_func(
    world,
    AI.PlanStep{
      AI.planner_decide_func(goal, observation),
      AI.PlanEnd{}
    }
  )

assert GeneratedPlanExecutionAssert_func:
  forall world: AI.World
  forall goal: AI.Goal
  forall observation: AI.Observation
  GeneratedPlanExecutionClaim_func(world, goal, observation)

def GeneratedPlanExecutionAssert_func(world, goal, observation):
  PlanExecutionInvariantAssert_func(
    world,
    AI.PlanStep{
      AI.planner_decide_func(goal, observation),
      AI.PlanEnd{}
    }
  )

# FiniteHistoryInvariantClaim-Section
# ===================================

# End-to-end structural theorem over every finite plan history and every
# starting world: actual IDs and count survive all executions, and every
# constructive Decision in the history is legal.
# Finite history uses the proof-carrying AI.Verified3 execution core.

assert FiniteHistoryInvariantClaim_func:
  forall -history: AI.PlanHistory
  forall -world: AI.World
  Type

def FiniteHistoryInvariantClaim_func(history, world):
  AI.Verified3<
    AI.World,
    output => {
      AI.world_agent_ids(output) == AI.world_agent_ids(world) : List<Nat>
    },
    output => {
      AI.world_agent_count(output) == AI.world_agent_count(world) : Nat
    },
    output => {AI.plan_history_all_legal(history) == True{} : Bool}
  >

assert FiniteHistoryInvariantAssert_func:
  forall history: AI.PlanHistory
  forall world: AI.World
  FiniteHistoryInvariantClaim_func(history, world)

def FiniteHistoryInvariantAssert_func(history, world):
  AI.world_execute_history_claim_func(history, world)

# ReplayDeterminismClaim-Section
# ==============================

assert ReplayDeterminismClaim_func:
  forall -left_history: AI.History
  forall -right_history: AI.History
  forall -left_world: AI.World
  forall -right_world: AI.World
  Type

def ReplayDeterminismClaim_func(left_history, right_history, left_world, right_world):
  {
    AI.world_simulate_func(left_history, left_world)
    == AI.world_simulate_func(right_history, right_world)
    : AI.Simulation
  }

assert ReplayDeterminismAssert_func:
  forall left_history: AI.History
  forall right_history: AI.History
  forall left_world: AI.World
  forall right_world: AI.World
  forall history_equal: {left_history == right_history : AI.History}
  forall world_equal: {left_world == right_world : AI.World}
  ReplayDeterminismClaim_func( left_history, right_history, left_world, right_world )

def ReplayDeterminismAssert_func(left_history, right_history, left_world, right_world, history_equal, world_equal):
  Equal.trans(
    AI.Simulation,
    AI.world_simulate_func(left_history, left_world),
    AI.world_simulate_func(right_history, left_world),
    AI.world_simulate_func(right_history, right_world),
    Equal.cong(
      AI.History,
      AI.Simulation,
      history => AI.world_simulate_func(history, left_world),
      left_history,
      right_history,
      history_equal
    ),
    Equal.cong(
      AI.World,
      AI.Simulation,
      world => AI.world_simulate_func(right_history, world),
      left_world,
      right_world,
      world_equal
    )
  )

assert verification_audit_func:
  VerificationAudit

def verification_audit_func():
  VerificationAudit{
    DecisionLegalityAssert_func,
    PlannerLegalityAssert_func,
    PlannerDeterminismAssert_func,
    AgentExecutionAssert_func,
    PlanExecutionInvariantAssert_func,
    GeneratedPlanExecutionAssert_func,
    FiniteHistoryInvariantAssert_func,
    ReplayDeterminismAssert_func,
    U32.from_nat(8n),
    U32.from_nat(5n),
    U32.from_nat(3n)
  }

assert verification_consume_func:
  forall -decision_legality: @decision: AI.Decision -> DecisionLegalityClaim_func(decision)
  forall -planner_legality: @goal: AI.Goal -> @observation: AI.Observation -> PlannerLegalityClaim_func(goal, observation)
  forall -arbitrary_execution: @world: AI.World -> @plan: AI.Plan -> PlanExecutionInvariantClaim_func(world, plan)
  forall -generated_execution: @world: AI.World -> @goal: AI.Goal -> @observation: AI.Observation -> GeneratedPlanExecutionClaim_func(world, goal, observation)
  forall -history: @events: AI.PlanHistory -> @world: AI.World -> FiniteHistoryInvariantClaim_func(events, world)
  Bool

def verification_consume_func(decision_legality, planner_legality, arbitrary_execution, generated_execution, history):
  True{}

assert ai_semantic_verification_func:
  Bool

def ai_semantic_verification_func():
  verification_consume_func(
    DecisionLegalityAssert_func,
    PlannerLegalityAssert_func,
    PlanExecutionInvariantAssert_func,
    GeneratedPlanExecutionAssert_func,
    FiniteHistoryInvariantAssert_func
  )
