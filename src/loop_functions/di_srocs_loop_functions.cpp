#include "di_srocs_loop_functions.h"

#include <argos3/plugins/simulator/entities/debug_entity.h>
#include <argos3/plugins/simulator/entities/block_entity.h>
#include <argos3/plugins/robots/builderbot/simulator/builderbot_entity.h>

namespace argos {

   /****************************************/
   /****************************************/

   CDISRoCSLoopFunctions::CDISRoCSLoopFunctions() {}

   /****************************************/
   /****************************************/

   void CDISRoCSLoopFunctions::Init(TConfigurationNode& t_tree) {
      /* parse loop function configuration */
      TConfigurationNodeIterator itCondition("condition");
      for(itCondition = itCondition.begin(&t_tree);
          itCondition != itCondition.end();
          ++itCondition) {
         /* parse the condition */
         m_vecConditions.emplace_back(ParseCondition(*itCondition));
      }
   }

   /****************************************/
   /****************************************/

   void CDISRoCSLoopFunctions::Reset() {
      /* remove all dynamically added entities */
      for(CEntity* pc_entity : m_vecAddedEntities) {
         CallEntityOperation<CSpaceOperationRemoveEntity, CSpace, void>(GetSpace(), *pc_entity);
      }
      m_vecAddedEntities.clear();
      /* clear is experiment finished */
      m_bTerminate = false;
      /* clear map of timers */
      m_mapTimers.clear();
      /* clear output streams */
      m_mapOutputStreams.clear();
      /* reenable all conditions */
      for(std::unique_ptr<SCondition>& ptr_condition : m_vecConditions) {
         ptr_condition->Enabled = true;
      }     
   }

   /****************************************/
   /****************************************/

   void CDISRoCSLoopFunctions::PreStep() {
      UInt32 unClock = GetSpace().GetSimulationClock();
      /* increment all timers */
      for(std::pair<const std::string, UInt32>& c_timer : m_mapTimers) {
         std::get<UInt32>(c_timer)++;
      }
      /* check conditions */
      for(std::unique_ptr<SCondition>& ptr_condition : m_vecConditions) {
         if(ptr_condition->Enabled && ptr_condition->IsTrue()) {
            /* schedule the associated actions */
            for(const std::shared_ptr<SAction>& ptr_action : ptr_condition->Actions) {
               m_mapPendingActions.emplace(unClock + ptr_action->Delay, ptr_action);
            }
            if(ptr_condition->Once) {
               ptr_condition->Enabled = false;
            }
         }
      }
      /* execute actions for the current timestep */
      std::pair<std::multimap<UInt32, std::shared_ptr<SAction> >::iterator,
                std::multimap<UInt32, std::shared_ptr<SAction> >::iterator> cActionRange =
         m_mapPendingActions.equal_range(unClock);
      for(std::multimap<UInt32, std::shared_ptr<SAction> >::iterator itAction = cActionRange.first;
          itAction != cActionRange.second;
          ++itAction) {
         itAction->second->Execute();
      }
      m_mapPendingActions.erase(unClock);
   }

   /****************************************/
   /****************************************/

   void CDISRoCSLoopFunctions::PostStep() {
      using TValueType = std::pair<const std::string, CAny>;
      try {
         for(TValueType& t_robot : GetSpace().GetEntitiesByType("builderbot")) {
            CBuilderBotEntity* pcBuilderBot =
               any_cast<CBuilderBotEntity*>(t_robot.second);
            LogEntityToFile(t_robot.first,
                            pcBuilderBot->GetEmbodiedEntity(),
                            pcBuilderBot->GetDebugEntity());
         }
      }
      catch(CARGoSException &ex) {}
      try {
         for(TValueType& t_block : GetSpace().GetEntitiesByType("block")) {
            CBlockEntity* pcBlock =
               any_cast<CBlockEntity*>(t_block.second);
            LogEntityToFile(t_block.first,
                            pcBlock->GetEmbodiedEntity(),
                            pcBlock->GetDebugEntity());
         }
      }
      catch(CARGoSException &ex) {}
   }
   
   /****************************************/
   /****************************************/

   bool CDISRoCSLoopFunctions::IsExperimentFinished() {
      return m_bTerminate;
   }

   /****************************************/
   /****************************************/
   
   std::unique_ptr<CDISRoCSLoopFunctions::SCondition>
      CDISRoCSLoopFunctions::ParseCondition(TConfigurationNode& t_tree) {
      std::vector<std::shared_ptr<SAction> > vecActions;
      TConfigurationNodeIterator itAction("action");
      for(itAction = itAction.begin(&t_tree);
          itAction != itAction.end();
          ++itAction) {
         vecActions.emplace_back(ParseAction(*itAction));
      }
      std::string strConditionType;
      bool bOnce = false;
      GetNodeAttribute(t_tree, "type", strConditionType);
      GetNodeAttributeOrDefault(t_tree, "once", bOnce, bOnce);
      if(strConditionType == "all") {
         std::vector<std::unique_ptr<SCondition> > vecConditions;
         TConfigurationNodeIterator itCondition("condition");
         for(itCondition = itCondition.begin(&t_tree);
            itCondition != itCondition.end();
            ++itCondition) {
            /* parse the condition */
            vecConditions.emplace_back(ParseCondition(*itCondition));
         }
         return std::make_unique<SAllCondition>(*this,
                                                bOnce,
                                                std::move(vecActions),
                                                std::move(vecConditions));
      }
      else if(strConditionType == "any") {
         std::vector<std::unique_ptr<SCondition> > vecConditions;
         TConfigurationNodeIterator itCondition("condition");
         for(itCondition = itCondition.begin(&t_tree);
            itCondition != itCondition.end();
            ++itCondition) {
            /* parse the condition */
            vecConditions.emplace_back(ParseCondition(*itCondition));
         }
         return std::make_unique<SAnyCondition>(*this,
                                                bOnce,
                                                std::move(vecActions),
                                                std::move(vecConditions));
      }
      else if(strConditionType == "entity") {
         std::string strTarget;
         std::string strId;
         std::string strType;
         CVector3 cPosition;
         Real fThreshold;
         GetNodeAttribute(t_tree, "target", strTarget);
         std::string::size_type nSeperator = strTarget.find(':');
         if(nSeperator != std::string::npos) {
            strType = std::move(strTarget.substr(0, nSeperator));
            strId = std::move(strTarget.substr(nSeperator + 1));
         }
         else {
            strId = std::move(strTarget);
         }
         GetNodeAttribute(t_tree, "position", cPosition);
         GetNodeAttribute(t_tree, "threshold", fThreshold);
         return std::make_unique<SEntityCondition>(*this,
                                                   bOnce,
                                                   std::move(vecActions),
                                                   std::move(strId),
                                                   std::move(strType),
                                                   cPosition,
                                                   fThreshold);
      }
      else if(strConditionType == "timer") {
         std::string strId;
         UInt32 unValue;
         GetNodeAttribute(t_tree, "id", strId);
         GetNodeAttribute(t_tree, "value", unValue);
         return std::make_unique<STimerCondition>(*this,
                                                  bOnce,
                                                  std::move(vecActions),
                                                  std::move(strId),
                                                  unValue);
      }
      else {
         THROW_ARGOSEXCEPTION("Loop function condition type \"" << strConditionType << "\" not implemented.");
      }
   }

   /****************************************/
   /****************************************/

   std::shared_ptr<CDISRoCSLoopFunctions::SAction> 
      CDISRoCSLoopFunctions::ParseAction(TConfigurationNode& t_tree) {
      std::string strActionType;
      UInt32 unDelay = 0;
      GetNodeAttribute(t_tree, "type", strActionType);
      GetNodeAttributeOrDefault(t_tree, "delay", unDelay, unDelay);
      if(strActionType == "add_timer") {
         std::string strId;
         GetNodeAttribute(t_tree, "id", strId);
         return std::make_shared<SAddTimerAction>(*this, unDelay, std::move(strId));
      }
      else if(strActionType == "add_entity") {
         TConfigurationNodeIterator itEntity;
         itEntity = itEntity.begin(&t_tree);
         if(itEntity == itEntity.end()) {
            THROW_ARGOSEXCEPTION("No entity provided in an add_entity action");
         }
         return std::make_shared<SAddEntityAction>(*this, unDelay, *itEntity);
      }
      else if(strActionType == "terminate") {
         return std::make_shared<STerminateAction>(*this, unDelay);
      }
      else {
         THROW_ARGOSEXCEPTION("Loop function action type \"" << strActionType << "\" not implemented.");
      }
   }

   /****************************************/
   /****************************************/

   void CDISRoCSLoopFunctions::LogEntityToFile(const std::string& str_entity_id,
                                               const CEmbodiedEntity& c_embodied_entity,
                                               const CDebugEntity& c_debug_entity) {
      UInt32 unClock = GetSpace().GetSimulationClock();
      std::map<std::string, std::ofstream>::iterator itOutputStream =
         m_mapOutputStreams.find(str_entity_id);
      if(itOutputStream == std::end(m_mapOutputStreams)) {
         std::pair<std::map<std::string, std::ofstream>::iterator, bool> cResult =
            m_mapOutputStreams.emplace(std::piecewise_construct,
                                       std::forward_as_tuple(str_entity_id),
                                       std::forward_as_tuple(str_entity_id + ".csv",
                                                             std::ios_base::out |
                                                             std::ios_base::trunc));
         if(cResult.second) {
            itOutputStream = cResult.first;
         }
         else {
            THROW_ARGOSEXCEPTION("Could not insert output stream into map");
         }
      }
      std::string strOutputBuffer(c_debug_entity.GetBuffer("loop_functions"));
      std::string::iterator itRemove =
         std::remove(std::begin(strOutputBuffer), std::end(strOutputBuffer), '\n');
      strOutputBuffer.erase(itRemove, std::end(strOutputBuffer));
      itOutputStream->second 
         << unClock
         << ","
         << c_embodied_entity.GetOriginAnchor().Position
         << ","
         << strOutputBuffer
         << std::endl;
   }

   /****************************************/
   /****************************************/

   bool CDISRoCSLoopFunctions::SAnyCondition::IsTrue() {
      for(std::unique_ptr<SCondition>& ptr_condition : Conditions) {
         if(ptr_condition->IsTrue()) {
            return true;
         }
      }
      return false;
   }

   /****************************************/
   /****************************************/

   bool CDISRoCSLoopFunctions::SAllCondition::IsTrue() {
      for(std::unique_ptr<SCondition>& ptr_condition : Conditions) {
         if(!ptr_condition->IsTrue()) {
            return false;
         }
      }
      return true;
   }

   /****************************************/
   /****************************************/

   bool CDISRoCSLoopFunctions::SEntityCondition::IsTrue() {
      try {
         std::vector<CEntity*> vecCandidateEntities;
         if(!EntityType.empty()) {
            for(CEntity* pc_entity : Parent.GetSpace().GetRootEntityVector()) {
               if(pc_entity->GetTypeDescription() == EntityType) {
                  if(!EntityId.empty() && (pc_entity->GetId() != EntityId)) {
                     continue;
                  }
                  vecCandidateEntities.push_back(pc_entity);
               }
            }
         }
         else {
            vecCandidateEntities.push_back(&Parent.GetSpace().GetEntity(EntityId));
         }
         for(CEntity* pc_entity : vecCandidateEntities) {
            CComposableEntity* pcComposableEntity =
               dynamic_cast<CComposableEntity*>(pc_entity);
            if(pcComposableEntity != nullptr && pcComposableEntity->HasComponent("body")) {
               CEmbodiedEntity& cEmbodiedEntity =
                  pcComposableEntity->GetComponent<CEmbodiedEntity>("body");
               Real fDistance =
                  Distance(Position, cEmbodiedEntity.GetOriginAnchor().Position);
               if(fDistance < Threshold) {
                  return true;
               }
            }
         }
      }
      catch(CARGoSException& ex) {}
      /* if we reach this point the condition is false */
      return false;
   }

   /****************************************/
   /****************************************/

   bool CDISRoCSLoopFunctions::STimerCondition::IsTrue() {
      std::map<std::string, UInt32>::iterator itTimer =
         Parent.m_mapTimers.find(TimerId);
      if(itTimer != std::end(Parent.m_mapTimers)) {
         return (itTimer->second == Value);
      }
      return false;
   }

   /****************************************/
   /****************************************/

   void CDISRoCSLoopFunctions::SAddEntityAction::Execute() {
      CEntity* pcEntity = CFactory<CEntity>::New(Configuration.Value());
      pcEntity->Init(Configuration);
      CallEntityOperation<CSpaceOperationAddEntity, CSpace, void>(Parent.GetSpace(), *pcEntity);
      /* attempt to do a collision check */
      CComposableEntity* pcComposableEntity =
         dynamic_cast<CComposableEntity*>(pcEntity);
      if((pcComposableEntity != nullptr) && pcComposableEntity->HasComponent("body")) {
         CEmbodiedEntity& cEmbodiedEntity =
            pcComposableEntity->GetComponent<CEmbodiedEntity>("body");
         if(cEmbodiedEntity.IsCollidingWithSomething()) {
            LOGERR << "[WARNING] Failed to add entity \"" 
                   << pcEntity->GetId()
                   << "\" since it would have collided with something"
                   << std::endl;
            CallEntityOperation<CSpaceOperationRemoveEntity, CSpace, void>(Parent.GetSpace(), *pcEntity);
         }
         else {
            /* entity added successfully */
            Parent.m_vecAddedEntities.push_back(pcEntity);
            return;
         }
      }
      LOGERR << "[WARNING] Could not perform collision test for entity \""
             << pcEntity->GetId()
             << std::endl;
   }

   /****************************************/
   /****************************************/

   void CDISRoCSLoopFunctions::SAddTimerAction::Execute() {
      if(Parent.m_mapTimers.count(TimerId) != 0) {
         LOGERR << "[WARNING] Timer \""
                << TimerId
                << "\" already exists and has been reset to zero"
                << std::endl;
      }
      Parent.m_mapTimers[TimerId] = 0;
   }

   /****************************************/
   /****************************************/

   void CDISRoCSLoopFunctions::STerminateAction::Execute() {
      Parent.m_bTerminate = true;
   }

   /****************************************/
   /****************************************/

   REGISTER_LOOP_FUNCTIONS(CDISRoCSLoopFunctions, "di_srocs_loop_functions");

}
