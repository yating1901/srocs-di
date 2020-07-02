#ifndef DI_SROCS_LOOP_FUNCTIONS_H
#define DI_SROCS_LOOP_FUNCTIONS_H

namespace argos {
   class CBlockEntity;
   class CBuilderBotEntity;
   class CEmbodiedEntity;
   class CDebugEntity;
}

#include <argos3/core/simulator/space/space.h>
#include <argos3/core/simulator/loop_functions.h>

#include <argos3/core/utility/math/vector3.h>
#include <argos3/core/utility/math/range.h>

namespace argos {

   class CDISRoCSLoopFunctions : public CLoopFunctions {

   public:

      CDISRoCSLoopFunctions();

      virtual ~CDISRoCSLoopFunctions() {}

      virtual void Init(TConfigurationNode& t_tree) override;

      virtual void Reset() override;

      virtual void PreStep() override;

      virtual void PostStep() override;

      virtual bool IsExperimentFinished() override;

   private:

      struct SAction {
         SAction(CDISRoCSLoopFunctions& c_parent,
                 UInt32 un_delay) :
            Parent(c_parent),
            Delay(un_delay) {}
         virtual void Execute() = 0;
         CDISRoCSLoopFunctions& Parent;
         const UInt32 Delay = 0;
      };

      struct SCondition {
         SCondition(CDISRoCSLoopFunctions& c_parent,
                    bool b_once,
                    std::vector<std::shared_ptr<SAction> >&& vec_actions) :
            Parent(c_parent),
            Once(b_once),
            Enabled(true),
            Actions(std::move(vec_actions)) {}
         virtual bool IsTrue() = 0;
         CDISRoCSLoopFunctions& Parent;
         bool Once;
         bool Enabled;
         std::vector<std::shared_ptr<SAction> > Actions;
      };

   private:

      std::unique_ptr<SCondition> ParseCondition(TConfigurationNode& t_tree);

      std::shared_ptr<SAction> ParseAction(TConfigurationNode& t_tree);

      void LogEntityToFile(const std::string& str_entity_id,
                           const CEmbodiedEntity& c_entity,
                           const CDebugEntity& c_debug_entity);

   private:

      struct SAddEntityAction : SAction {
         SAddEntityAction(CDISRoCSLoopFunctions& c_parent,
                          UInt32 un_delay,
                          const TConfigurationNode& t_configuration) :
            SAction(c_parent, un_delay),
            Configuration(t_configuration) {}
         virtual void Execute() override;
         TConfigurationNode Configuration;
      };

      struct SAddTimerAction : SAction {
         SAddTimerAction(CDISRoCSLoopFunctions& c_parent,
                         UInt32 un_delay,
                         std::string&& str_timer_id) :
            SAction(c_parent, un_delay),
            TimerId(std::move(str_timer_id)) {}
         virtual void Execute() override;
         std::string TimerId;
      };

      struct STerminateAction : SAction {
         STerminateAction(CDISRoCSLoopFunctions& c_parent,
                          UInt32 un_delay) :
            SAction(c_parent, un_delay) {}
         virtual void Execute() override;
      };

      struct SAnyCondition : SCondition {
         SAnyCondition(CDISRoCSLoopFunctions& c_parent,
                       bool b_once,
                       std::vector<std::shared_ptr<SAction> >&& vec_actions,
                       std::vector<std::unique_ptr<SCondition> >&& vec_conditions) :
            SCondition(c_parent, b_once, std::move(vec_actions)),
            Conditions(std::move(vec_conditions)) {}
         virtual bool IsTrue() override;
         std::vector<std::unique_ptr<SCondition> > Conditions;
      };

      struct SAllCondition : SCondition {
         SAllCondition(CDISRoCSLoopFunctions& c_parent,
                       bool b_once,
                       std::vector<std::shared_ptr<SAction> >&& vec_actions,
                       std::vector<std::unique_ptr<SCondition> >&& vec_conditions) :
            SCondition(c_parent, b_once, std::move(vec_actions)),
            Conditions(std::move(vec_conditions)) {}
         virtual bool IsTrue() override;
         std::vector<std::unique_ptr<SCondition> > Conditions;
      };

      struct SEntityCondition : SCondition {
         SEntityCondition(CDISRoCSLoopFunctions& c_parent,
                          bool b_once,
                          std::vector<std::shared_ptr<SAction> >&& vec_actions,
                          std::string&& str_entity_id,
                          std::string&& str_entity_type,
                          const CVector3& c_position,
                          Real f_threshold = 0.0f) :
            SCondition(c_parent, b_once, std::move(vec_actions)),
            EntityId(std::move(str_entity_id)),
            EntityType(std::move(str_entity_type)),
            Position(c_position),
            Threshold(f_threshold) {}
         virtual bool IsTrue() override;
         std::string EntityId;
         std::string EntityType;
         CVector3 Position;
         Real Threshold;
      };

      struct STimerCondition : SCondition {
         STimerCondition(CDISRoCSLoopFunctions& c_parent,
                         bool b_once,
                         std::vector<std::shared_ptr<SAction> >&& vec_actions,
                         std::string&& str_timer_id,
                         UInt32 un_value) :
            SCondition(c_parent, b_once, std::move(vec_actions)),
            TimerId(str_timer_id),
            Value(un_value) {}
         virtual bool IsTrue() override;
         std::string TimerId;
         UInt32 Value;
      };

      std::vector<std::unique_ptr<SCondition> > m_vecConditions;
      std::multimap<UInt32, std::shared_ptr<SAction> > m_mapPendingActions;
      std::vector<CEntity*> m_vecAddedEntities;

      std::map<std::string, UInt32> m_mapTimers;
      std::map<std::string, std::ofstream> m_mapOutputStreams;

      bool m_bTerminate = false;

   };


}

#endif

