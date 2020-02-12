#include "di_qtopengl_user_functions.h"

#include <argos3/core/simulator/simulator.h>
#include <argos3/core/simulator/space/space.h>
#include <argos3/core/simulator/entity/composable_entity.h>

#include <argos3/plugins/simulator/visualizations/qt-opengl/qtopengl_render.h>
#include <argos3/plugins/simulator/visualizations/qt-opengl/qtopengl_main_window.h>
#include <argos3/plugins/simulator/entities/debug_entity.h>

#include <QWheelEvent>

#define GL_NUMBER_VERTICES 36u
#define BLOCK_SIDE_LENGTH 0.055
#define DELTA_Z 0.0005

namespace argos {

   /********************************************************************************/
   /********************************************************************************/

   bool CDIQtOpenGLUserFunctionsMouseWheelEventHandler::eventFilter(QObject* pc_object,
                                                                     QEvent* pc_event) {
      if (pc_event->type() != QEvent::Wheel) {
         return QObject::eventFilter(pc_object, pc_event);
      }
      QWheelEvent *pcWheelEvent = static_cast<QWheelEvent*>(pc_event);
      if(!(pcWheelEvent->modifiers() & Qt::ControlModifier)) {
         return QObject::eventFilter(pc_object, pc_event);
      }
      CEntity* pcEntity = m_pcUserFunctions->GetSelectedEntity();
      if(pcEntity == nullptr) {
         return QObject::eventFilter(pc_object, pc_event);
      }
      CBuilderBotEntity* pcBuilderBotEntity = dynamic_cast<CBuilderBotEntity*>(pcEntity);
      if(pcBuilderBotEntity == nullptr) {
         return QObject::eventFilter(pc_object, pc_event);
      }
      CEmbodiedEntity& cBuilderBotEmbodiedEntity = pcBuilderBotEntity->GetEmbodiedEntity();
      const SAnchor& sBuilderBotOriginAnchor = cBuilderBotEmbodiedEntity.GetOriginAnchor();
      const SAnchor& sBuilderBotEndEffectorAnchor = cBuilderBotEmbodiedEntity.GetAnchor("end_effector");
      /* get the target position of a block */
      CVector3 cTargetBlockPos(sBuilderBotEndEffectorAnchor.Position);
      cTargetBlockPos -= (CVector3::Z * BLOCK_SIDE_LENGTH);
      try {
         std::map<std::string, CAny>& mapBlockEntities =
            CSimulator::GetInstance().GetSpace().GetEntitiesByType("block");
         for(const std::pair<const std::string, CAny>& c_block : mapBlockEntities) {
            CEmbodiedEntity& cBlockEmbodiedEntity =
               any_cast<CBlockEntity*>(c_block.second)->GetEmbodiedEntity();
            const SAnchor& sBlockOriginAnchor = cBlockEmbodiedEntity.GetOriginAnchor();
            if(Distance(cTargetBlockPos, sBlockOriginAnchor.Position) < 0.005) {
               /* we have found our block, save its position and move it to just below the floor */
               const CVector3 cBlockInitPosition(sBlockOriginAnchor.Position);
               const CQuaternion cBlockInitOrientation(sBlockOriginAnchor.Orientation);
               const CVector3 cBuilderBotInitPosition(sBuilderBotOriginAnchor.Position);
               const CQuaternion cBuilderBotInitOrientation(sBuilderBotOriginAnchor.Orientation);
               // step one: move the block to a temporary position */
               CVector3 cBlockTempPosition(cBlockInitPosition);
               cBlockTempPosition.SetZ(-2.0 * BLOCK_SIDE_LENGTH);
               if(cBlockEmbodiedEntity.MoveTo(cBlockTempPosition,
                                              sBlockOriginAnchor.Orientation)) {
                  CDegrees cDegrees(pcWheelEvent->angleDelta().y() / 8);
                  CQuaternion cRotation(ToRadians(cDegrees), CVector3::Z);
                  // step two: rotate the builderbot
                  if(cBuilderBotEmbodiedEntity.MoveTo(cBuilderBotInitPosition,
                                                      cBuilderBotInitOrientation * cRotation)) {
                     // step three: rotate and translate the block
                     CVector3 cBlockNewPosition(cBlockInitPosition - cBuilderBotInitPosition);
                     cBlockNewPosition.Rotate(cRotation);
                     cBlockNewPosition += cBuilderBotInitPosition;
                     Real fBlockEndEffectorDistance =
                        Distance(cBlockNewPosition, sBuilderBotEndEffectorAnchor.Position);
                     if(fBlockEndEffectorDistance < BLOCK_SIDE_LENGTH + DELTA_Z) {
                        cBlockNewPosition -= (CVector3::Z * DELTA_Z);
                     }
                     CQuaternion cBlockNewOrientation(cBlockInitOrientation * cRotation);
                     if(cBlockEmbodiedEntity.MoveTo(cBlockNewPosition,
                                                    cBlockNewOrientation)) {
                        m_pcUserFunctions->GetQTOpenGLWidget().update();
                        return true;
                     }
                  }
               }
               cBuilderBotEmbodiedEntity.MoveTo(cBuilderBotInitPosition, cBuilderBotInitOrientation);
               cBlockEmbodiedEntity.MoveTo(cBlockInitPosition, cBlockInitOrientation);
               return true;
            }
         }
      }
      catch(CARGoSException& ex) {}
      return QObject::eventFilter(pc_object, pc_event);
   }

   /********************************************************************************/
   /********************************************************************************/

   CDIQtOpenGLUserFunctions::CDIQtOpenGLUserFunctions() :
      m_unCameraIndex(0),
      m_unLastSimulationClock(-1) {
      RegisterUserFunction<CDIQtOpenGLUserFunctions, CBuilderBotEntity>(&CDIQtOpenGLUserFunctions::Annotate);
      RegisterUserFunction<CDIQtOpenGLUserFunctions, CPiPuckEntity>(&CDIQtOpenGLUserFunctions::Annotate);
      RegisterUserFunction<CDIQtOpenGLUserFunctions, CDroneEntity>(&CDIQtOpenGLUserFunctions::Annotate);
   }

   /********************************************************************************/
   /********************************************************************************/

   CDIQtOpenGLUserFunctions::~CDIQtOpenGLUserFunctions() {}

   /********************************************************************************/
   /********************************************************************************/

   void CDIQtOpenGLUserFunctions::Init(TConfigurationNode& t_tree) {
      /* install the mouse wheel event handler */
      m_pcMouseWheelEventHandler =
         new CDIQtOpenGLUserFunctionsMouseWheelEventHandler(&GetQTOpenGLWidget(), this);
      GetQTOpenGLWidget().installEventFilter(m_pcMouseWheelEventHandler);
      /* set up the camera paths */
      if(NodeExists(t_tree, "camera_paths")) {
         TConfigurationNode& tCameraPaths = GetNode(t_tree, "camera_paths");
         GetNodeAttribute(tCameraPaths, "use_camera", m_unCameraIndex);
         if(m_unCameraIndex > 11) {
            THROW_ARGOSEXCEPTION("use_camera must be in the range [0:11].");
         }
         TConfigurationNodeIterator itPath("path");
         UInt32 unDuration, unStartFocalLength, unEndFocalLength;
         CVector3 cStartPosition, cEndPosition, cStartLookAt, cEndLookAt, cStartUp, cEndUp;
         for(itPath = itPath.begin(&tCameraPaths); itPath != itPath.end(); ++itPath) {
            GetNodeAttribute(*itPath, "duration", unDuration);
            TConfigurationNode tStartNode = GetNode(*itPath, "start");
            GetNodeAttribute(tStartNode, "position", cStartPosition);
            GetNodeAttribute(tStartNode, "look_at", cStartLookAt);
            GetNodeAttributeOrDefault(tStartNode, "up", cStartUp, cStartUp);
            GetNodeAttribute(tStartNode, "lens_focal_length", unStartFocalLength);
            TConfigurationNode tEndNode = GetNode(*itPath, "end");
            GetNodeAttribute(tEndNode, "position", cEndPosition);
            GetNodeAttribute(tEndNode, "look_at", cEndLookAt);
            GetNodeAttributeOrDefault(tEndNode, "up", cEndUp, cEndUp);
            GetNodeAttribute(tEndNode, "lens_focal_length", unEndFocalLength);
            m_vecCameraPaths.emplace_back(unDuration,
                                          unStartFocalLength,
                                          unEndFocalLength,
                                          cStartPosition,
                                          cEndPosition,
                                          cStartLookAt,
                                          cEndLookAt,
                                          cStartUp,
                                          cEndUp);
         }
      }
   }



   /********************************************************************************/
   /********************************************************************************/

   void CDIQtOpenGLUserFunctions::DrawInWorld() {
      UInt32 unSimulationClock = CSimulator::GetInstance().GetSpace().GetSimulationClock();
      if(m_unLastSimulationClock != unSimulationClock) {
         m_unLastSimulationClock = unSimulationClock;
         /* get camera settings */
         CQTOpenGLCamera::SSettings& sSettings = 
            GetQTOpenGLWidget().GetCamera().GetSetting(m_unCameraIndex);
         /* find current camera path */
         UInt32 unPreviousPathDurations = 0;
         for(const SCameraPath& s_camera_path : m_vecCameraPaths) {
            if(unPreviousPathDurations + s_camera_path.Duration < unSimulationClock) {
               unPreviousPathDurations += s_camera_path.Duration;
            }
            else {
               Real fPathTimeFraction =
                  static_cast<Real>(unSimulationClock - unPreviousPathDurations) /
                  static_cast<Real>(s_camera_path.Duration);
               CVector3 cPosition(s_camera_path.EndPosition - s_camera_path.StartPosition);
               cPosition *= fPathTimeFraction;
               cPosition += s_camera_path.StartPosition;
               CVector3 cLookAt(s_camera_path.EndLookAt - s_camera_path.StartLookAt);
               cLookAt *= fPathTimeFraction;
               cLookAt += s_camera_path.StartLookAt;
               CVector3 cUp(s_camera_path.EndUp - s_camera_path.StartUp);
               cUp *= fPathTimeFraction;
               cUp += s_camera_path.StartUp;
               sSettings.Position = cPosition;
               sSettings.Target = cLookAt;
               sSettings.Forward = 
                  (sSettings.Target - sSettings.Position).Normalize();
               if(cUp == CVector3::ZERO) {
                  if(sSettings.Forward.GetX() != 0 || sSettings.Forward.GetY() != 0) {
                     CVector2 cLeftXY(sSettings.Forward.GetX(), sSettings.Forward.GetY());
                     cLeftXY.Perpendicularize();
                     sSettings.Left.Set(cLeftXY.GetX(), cLeftXY.GetY(), 0.0f);
                     sSettings.Left.Normalize();
                  }
                  else {
                     sSettings.Left.Set(0.0f, 1.0f, 0.0f);
                  }
                  /* Calculate the Up vector with a cross product */
                  sSettings.Up = sSettings.Forward;
                  sSettings.Up.CrossProduct(sSettings.Left).Normalize();
               }
               else {
                  sSettings.Up = cUp;
                  sSettings.Up.Normalize();
                  /* Calculate the Left vector with a cross product */
                  sSettings.Left = sSettings.Up;
                  sSettings.Left.CrossProduct(sSettings.Forward).Normalize();
               }
               break;
            }
         }
      }
   }

   /********************************************************************************/
   /********************************************************************************/

   void CDIQtOpenGLUserFunctions::EntityMoved(CEntity& c_entity,
                                               const CVector3& c_old_pos,
                                               const CVector3& c_new_pos) {
      /* was a builderbot moved? */
      CBuilderBotEntity* pcBuilderBot = dynamic_cast<CBuilderBotEntity*>(&c_entity);
      if(pcBuilderBot == nullptr) {
         return;
      }
      /* at this point the end effector of the robot has already been moved,
         so we need to figure out where it was */
      const SAnchor& sEndEffectorAnchor =
         pcBuilderBot->GetEmbodiedEntity().GetAnchor("end_effector");
      CVector3 cDeltaPos(c_new_pos - c_old_pos);
      CVector3 cOldEndEffectorPos(sEndEffectorAnchor.Position - cDeltaPos);
      /* get the potential position of a block */
      CVector3 cBlockTestPos(cOldEndEffectorPos - CVector3::Z * BLOCK_SIDE_LENGTH);
      try {
         std::map<std::string, CAny>& mapBlockEntities =
            CSimulator::GetInstance().GetSpace().GetEntitiesByType("block");
         for(const std::pair<const std::string, CAny>& c_block : mapBlockEntities) {
            CEmbodiedEntity& cEmbodiedEntity =
               any_cast<CBlockEntity*>(c_block.second)->GetEmbodiedEntity();
            const SAnchor& sBlockAnchor = cEmbodiedEntity.GetOriginAnchor();
            /* if the origin of a block is within 0.005 meters of where
               we expected to find a block, move it */
            if(Distance(cBlockTestPos, sBlockAnchor.Position) < 0.005) {
               /* here, we drop the blocks position by 0.0005 meters to compensate for
                  inaccuracies in the physics engine */
               cEmbodiedEntity.MoveTo(sBlockAnchor.Position + cDeltaPos - (CVector3::Z * 0.0005),
                                      sBlockAnchor.Orientation);
               return;
            }
         }
      }
      catch(CARGoSException& ex) {}
   }

   /********************************************************************************/
   /********************************************************************************/

   void CDIQtOpenGLUserFunctions::Annotate(CDebugEntity& c_debug_entity,
                                            const SAnchor& s_anchor) {
      glDisable(GL_LIGHTING);
      glEnable(GL_BLEND);
      glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
      const CVector3& cPosition = s_anchor.Position;
      const CQuaternion& cOrientation = s_anchor.Orientation;
      CRadians cZAngle, cYAngle, cXAngle;
      cOrientation.ToEulerAngles(cZAngle, cYAngle, cXAngle);
      glPushMatrix();
      glTranslatef(cPosition.GetX(), cPosition.GetY(), cPosition.GetZ());
      glRotatef(ToDegrees(cXAngle).GetValue(), 1.0f, 0.0f, 0.0f);
      glRotatef(ToDegrees(cYAngle).GetValue(), 0.0f, 1.0f, 0.0f);
      glRotatef(ToDegrees(cZAngle).GetValue(), 0.0f, 0.0f, 1.0f);
      std::istringstream issInstructions, issArgument;
      issInstructions.str(c_debug_entity.GetBuffer("draw"));
      for(std::string strInstruction; std::getline(issInstructions, strInstruction); ) {
         std::vector<std::string> vecArguments;
         Tokenize(strInstruction, vecArguments, "()");
         if(vecArguments.size() == 4 && vecArguments[0] == "arrow") {
            CColor cColor;
            CVector3 cTo, cFrom;
            std::istringstream(vecArguments[1]) >> cColor;
            std::istringstream(vecArguments[2]) >> cFrom;
            std::istringstream(vecArguments[3]) >> cTo;
            glColor4ub(cColor.GetRed(), cColor.GetGreen(), cColor.GetBlue(), 128u);
            DrawArrow3(cFrom, cTo);
         }
         else if(vecArguments.size() == 4 && vecArguments[0] == "ring") {
            CColor cColor;
            CVector3 cCenter;
            Real fRadius;
            std::istringstream(vecArguments[1]) >> cColor;
            std::istringstream(vecArguments[2]) >> cCenter;
            std::istringstream(vecArguments[3]) >> fRadius;
            glColor4ub(cColor.GetRed(), cColor.GetGreen(), cColor.GetBlue(), 128u);
            DrawRing3(cCenter, fRadius);
         }
      }
      glPopMatrix();
      glDisable(GL_BLEND);
      glEnable(GL_LIGHTING);
   }

   /********************************************************************************/
   /********************************************************************************/

   void CDIQtOpenGLUserFunctions::DrawRing3(const CVector3& c_center, Real f_radius) {
      const CCachedShapes& cCachedShapes = CCachedShapes::GetCachedShapes();
      const Real fRingHeight = 0.015625;
      const Real fRingThickness = 0.015625;
      const Real fHalfRingThickness = fRingThickness * 0.5;
      const Real fDiameter = 2.0 * f_radius;
      /* draw inner ring surface */
      glPushMatrix();
      glTranslatef(c_center.GetX(), c_center.GetY(), c_center.GetZ());
      glScalef(fDiameter, fDiameter, fRingHeight);
      glCallList(cCachedShapes.GetRing());
      glPopMatrix();
      /* draw outer ring surface */
      glPushMatrix();
      glTranslatef(c_center.GetX(), c_center.GetY(), c_center.GetZ());
      glScalef(fDiameter + fRingThickness, fDiameter + fRingThickness, fRingHeight);
      glCallList(cCachedShapes.GetRing());
      glPopMatrix();
      /* draw top */
      glPushMatrix();
      glTranslatef(c_center.GetX(), c_center.GetY(), c_center.GetZ());
      CVector2 cInnerVertex(f_radius, 0.0f);
      CVector2 cOuterVertex(f_radius + fHalfRingThickness, 0.0f);
      const CRadians cAngle(CRadians::TWO_PI / GL_NUMBER_VERTICES);
      glBegin(GL_QUAD_STRIP);
      glNormal3f(0.0f, 0.0f, 1.0f);
      for(GLuint i = 0; i <= GL_NUMBER_VERTICES; i++) {
         glVertex3f(cInnerVertex.GetX(), cInnerVertex.GetY(), fRingHeight);
         glVertex3f(cOuterVertex.GetX(), cOuterVertex.GetY(), fRingHeight);
         cInnerVertex.Rotate(cAngle);
         cOuterVertex.Rotate(cAngle);
      }
      glEnd();
      glPopMatrix();
   }

   /********************************************************************************/
   /********************************************************************************/

   void CDIQtOpenGLUserFunctions::DrawArrow3(const CVector3& c_from, const CVector3& c_to) {
      const CCachedShapes& cCachedShapes = CCachedShapes::GetCachedShapes();
      const Real fArrowThickness = 0.015625f;
      const Real fArrowHead =      0.031250f;
      CVector3 cArrow(c_to - c_from);
      CQuaternion cRotation(CVector3::Z, cArrow / cArrow.Length());
      CRadians cZAngle, cYAngle, cXAngle;
      cRotation.ToEulerAngles(cZAngle, cYAngle, cXAngle);
      /* draw arrow body */
      glPushMatrix();
      glTranslatef(c_to.GetX(), c_to.GetY(), c_to.GetZ());
      glRotatef(ToDegrees(cXAngle).GetValue(), 1.0f, 0.0f, 0.0f);
      glRotatef(ToDegrees(cYAngle).GetValue(), 0.0f, 1.0f, 0.0f);
      glRotatef(ToDegrees(cZAngle).GetValue(), 0.0f, 0.0f, 1.0f);
      glScalef(fArrowHead, fArrowHead, fArrowHead);
      glCallList(cCachedShapes.GetCone());
      glPopMatrix();
      /* draw arrow head */
      glPushMatrix();
      glTranslatef(c_from.GetX(), c_from.GetY(), c_from.GetZ());
      glRotatef(ToDegrees(cXAngle).GetValue(), 1.0f, 0.0f, 0.0f);
      glRotatef(ToDegrees(cYAngle).GetValue(), 0.0f, 1.0f, 0.0f);
      glRotatef(ToDegrees(cZAngle).GetValue(), 0.0f, 0.0f, 1.0f);
      glScalef(fArrowThickness, fArrowThickness, cArrow.Length() - fArrowHead);
      glCallList(cCachedShapes.GetCylinder());
      glPopMatrix();
   }

   /********************************************************************************/
   /********************************************************************************/

   void CDIQtOpenGLUserFunctions::CCachedShapes::MakeCylinder() {
      /* Side surface */
      CVector2 cVertex(0.5f, 0.0f);
      CRadians cAngle(CRadians::TWO_PI / GL_NUMBER_VERTICES);
      glBegin(GL_QUAD_STRIP);
      for(GLuint i = 0; i <= GL_NUMBER_VERTICES; i++) {
         glNormal3f(cVertex.GetX(), cVertex.GetY(), 0.0f);
         glVertex3f(cVertex.GetX(), cVertex.GetY(), 1.0f);
         glVertex3f(cVertex.GetX(), cVertex.GetY(), 0.0f);
         cVertex.Rotate(cAngle);
      }
      glEnd();
      /* Top disk */
      cVertex.Set(0.5f, 0.0f);
      glBegin(GL_POLYGON);
      glNormal3f(0.0f, 0.0f, 1.0f);
      for(GLuint i = 0; i <= GL_NUMBER_VERTICES; i++) {
         glVertex3f(cVertex.GetX(), cVertex.GetY(), 1.0f);
         cVertex.Rotate(cAngle);
      }
      glEnd();
      /* Bottom disk */
      cVertex.Set(0.5f, 0.0f);
      cAngle = -cAngle;
      glBegin(GL_POLYGON);
      glNormal3f(0.0f, 0.0f, -1.0f);
      for(GLuint i = 0; i <= GL_NUMBER_VERTICES; i++) {
         glVertex3f(cVertex.GetX(), cVertex.GetY(), 0.0f);
         cVertex.Rotate(cAngle);
      }
      glEnd();
   }

   /********************************************************************************/
   /********************************************************************************/

   void CDIQtOpenGLUserFunctions::CCachedShapes::MakeCone() {
      /* Cone surface */
      CVector2 cVertex(0.5f, 0.0f);
      CRadians cAngle(CRadians::TWO_PI / GL_NUMBER_VERTICES);
      glBegin(GL_QUAD_STRIP);
      for(GLuint i = 0; i <= GL_NUMBER_VERTICES; i++) {
         glNormal3f(cVertex.GetX(), cVertex.GetY(), 0.0f);
         glVertex3f(0.0f, 0.0f, 0.0f);
         glVertex3f(cVertex.GetX(), cVertex.GetY(), -1.0f);
         cVertex.Rotate(cAngle);
      }
      glEnd();
      /* Bottom disk */
      cVertex.Set(0.5f, 0.0f);
      cAngle = -cAngle;
      glBegin(GL_POLYGON);
      glNormal3f(0.0f, 0.0f, -1.0f);
      for(GLuint i = 0; i <= GL_NUMBER_VERTICES; i++) {
         glVertex3f(cVertex.GetX(), cVertex.GetY(), -1.0f);
         cVertex.Rotate(cAngle);
      }
      glEnd();
   }

   /********************************************************************************/
   /********************************************************************************/

   void CDIQtOpenGLUserFunctions::CCachedShapes::MakeRing() {
      CVector2 cVertex;
      const CRadians cAngle(CRadians::TWO_PI / GL_NUMBER_VERTICES);
      /* draw front surface */
      cVertex.Set(0.5f, 0.0f);     
      glBegin(GL_QUAD_STRIP);
      for(GLuint i = 0; i <= GL_NUMBER_VERTICES; i++) {
         glNormal3f(cVertex.GetX(), cVertex.GetY(), 0.0f);
         glVertex3f(cVertex.GetX(), cVertex.GetY(), 1.0f);
         glVertex3f(cVertex.GetX(), cVertex.GetY(), 0.0f);
         cVertex.Rotate(cAngle);
      }
      glEnd();
      /* draw back surface */
      cVertex.Set(0.5f, 0.0f);     
      glBegin(GL_QUAD_STRIP);
      for(GLuint i = 0; i <= GL_NUMBER_VERTICES; i++) {
         glNormal3f(cVertex.GetX(), cVertex.GetY(), 0.0f);
         glVertex3f(cVertex.GetX(), cVertex.GetY(), 0.0f);
         glVertex3f(cVertex.GetX(), cVertex.GetY(), 1.0f);
         cVertex.Rotate(cAngle);
      }
      glEnd();
   }

   /********************************************************************************/
   /********************************************************************************/

   REGISTER_QTOPENGL_USER_FUNCTIONS(CDIQtOpenGLUserFunctions, "di_qtopengl_user_functions");

   /********************************************************************************/
   /********************************************************************************/

}
