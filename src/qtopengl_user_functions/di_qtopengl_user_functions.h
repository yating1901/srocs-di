#ifndef DI_QTOPENGL_USER_FUNCTIONS_H
#define DI_QTOPENGL_USER_FUNCTIONS_H

namespace argos {
   class CDIQtOpenGLUserFunctions;
}

#include <argos3/plugins/simulator/visualizations/qt-opengl/qtopengl_user_functions.h>
#include <argos3/core/utility/datatypes/datatypes.h>
#include <argos3/plugins/simulator/entities/debug_entity.h>
#include <argos3/plugins/simulator/entities/block_entity.h>
#include <argos3/plugins/robots/builderbot/simulator/builderbot_entity.h>
#include <argos3/plugins/robots/pi-puck/simulator/pipuck_entity.h>
#include <argos3/plugins/robots/drone/simulator/drone_entity.h>

namespace argos {
   class CDIQtOpenGLUserFunctionsMouseWheelEventHandler : public QObject {
      Q_OBJECT

   public:
      CDIQtOpenGLUserFunctionsMouseWheelEventHandler(QObject* pc_parent,
                                                      CDIQtOpenGLUserFunctions* pc_user_functions) :
         QObject(pc_parent),
         m_pcUserFunctions(pc_user_functions) {}

   protected:
      bool eventFilter(QObject* pc_object, QEvent* pc_event);

   private:
      CDIQtOpenGLUserFunctions* m_pcUserFunctions;
   };

   class CDIQtOpenGLUserFunctions : public QObject,
                                     public CQTOpenGLUserFunctions {
      Q_OBJECT

   public:
      CDIQtOpenGLUserFunctions();

      virtual ~CDIQtOpenGLUserFunctions();

      virtual void Init(TConfigurationNode& t_tree);

      virtual void EntityMoved(CEntity& c_entity,
                               const CVector3& c_old_pos,
                               const CVector3& c_new_pos);

      inline void Annotate(CBuilderBotEntity& c_entity) {
         Annotate(c_entity.GetDebugEntity(),
                  c_entity.GetEmbodiedEntity().GetOriginAnchor());
      }

      inline void Annotate(CDroneEntity& c_entity) {
         Annotate(c_entity.GetDebugEntity(),
                  c_entity.GetEmbodiedEntity().GetOriginAnchor());
      }

      inline void Annotate(CPiPuckEntity& c_entity) {
         Annotate(c_entity.GetDebugEntity(),
                  c_entity.GetEmbodiedEntity().GetOriginAnchor());
      }

      void Annotate(CDebugEntity& c_debug_entity,
                    const SAnchor& s_anchor);

      virtual void DrawInWorld() override;

   private:
      struct SCameraPath {
         SCameraPath(UInt32 un_duration,
                     UInt32 un_start_focal_length,
                     UInt32 un_end_focal_length,
                     const CVector3& c_start_position,
                     const CVector3& c_end_position,
                     const CVector3& c_start_look_at,
                     const CVector3& c_end_look_at,
                     const CVector3& c_start_up = CVector3::ZERO,
                     const CVector3& c_end_up = CVector3::ZERO,
                     const SAnchor* ps_relative_to_anchor = nullptr) :
            Duration(un_duration),
            StartPosition(c_start_position),
            EndPosition(c_end_position),
            StartLookAt(c_start_look_at),
            EndLookAt(c_end_look_at),
            StartUp(c_start_up),
            EndUp(c_end_up),
            RelativeToAnchor(ps_relative_to_anchor) {}
         UInt32 Duration;
         UInt32 StartFocalLength;
         UInt32 EndFocalLength;
         CVector3 StartPosition;
         CVector3 EndPosition;
         CVector3 StartLookAt;
         CVector3 EndLookAt;
         CVector3 StartUp;
         CVector3 EndUp;
         const SAnchor* RelativeToAnchor;
      };

      std::vector<SCameraPath> m_vecCameraPaths;
      UInt32 m_unCameraIndex;
      UInt32 m_unLastSimulationClock;

      CDIQtOpenGLUserFunctionsMouseWheelEventHandler* m_pcMouseWheelEventHandler;

   private:

      void DrawArrow3(const CVector3& c_from, const CVector3& c_to);

      void DrawRing3(const CVector3& c_center, Real f_radius);

   private:

      struct CCachedShapes {
      public:
         static CCachedShapes& GetCachedShapes() {
            static CCachedShapes cInstance;
            return cInstance;
         }

         GLuint GetCylinder() const {
            return m_unCylinder;
         }

         GLuint GetCone() const {
            return m_unCone;
         }

         GLuint GetRing() const {
            return m_unRing;
         }

      private:
         CCachedShapes() {
            /* Reserve the needed display lists */
            m_unBaseList = glGenLists(3);
            /* References to the display lists */
            m_unCylinder = m_unBaseList;
            m_unCone     = m_unBaseList + 1;
            m_unRing     = m_unBaseList + 2;
            /* Make cylinder list */
            glNewList(m_unCylinder, GL_COMPILE);
            MakeCylinder();
            glEndList();
            /* Make cone list */
            glNewList(m_unCone, GL_COMPILE);
            MakeCone();
            glEndList();
            /* Make ring list */
            glNewList(m_unRing, GL_COMPILE);
            MakeRing();
            glEndList();
         }

         ~CCachedShapes() {
            glDeleteLists(m_unBaseList, 3);
         }

         void MakeCone();
         void MakeCylinder();
         void MakeRing();
   
         GLuint m_unBaseList;
         GLuint m_unCylinder;
         GLuint m_unCone;
         GLuint m_unRing;
      };
   };
}
#endif
