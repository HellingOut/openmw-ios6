#ifndef OPENMW_COMPONENTS_SCENEUTIL_LIGHTMANAGER_H
#define OPENMW_COMPONENTS_SCENEUTIL_LIGHTMANAGER_H

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <map>
#include <set>
#include <unordered_map>
#include <vector>

#include <osg/Light>

#include <osg/Group>
#include <osg/NodeVisitor>
#include <osg/observer_ptr>

namespace osgUtil
{
    class CullVisitor;
}

namespace SceneUtil
{

    /// LightSource managed by a LightManager.
    /// @par Typically used for point lights. Spot lights are not supported yet. Directional lights affect the whole scene
    ///     so do not need to be managed by a LightManager - so for directional lights use a plain osg::LightSource instead.
    /// @note LightSources must be decorated by a LightManager node in order to have an effect. Typical use would
    ///     be one LightManager as the root of the scene graph.
    /// @note One needs to attach LightListCallback's to the scene to have objects receive lighting from LightSources.
    ///     See the documentation of LightListCallback for more information.
    /// @note The position of the contained osg::Light is automatically updated based on the LightSource's world position.
    class LightSource : public osg::Node
    {
        // double buffered osg::Light's, since one of them may be in use by the draw thread at any given time
        osg::ref_ptr<osg::Light> mLight[2];

        // LightSource will affect objects within this radius
        float mRadius;

        int mId;

    public:

        META_Node(SceneUtil, LightSource)

        LightSource();

        LightSource(const LightSource& copy, const osg::CopyOp& copyop);

        float getRadius() const
        {
            return mRadius;
        }

        /// The LightSource will affect objects within this radius.
        void setRadius(float radius)
        {
            mRadius = radius;
        }

        /// Get the osg::Light safe for modification in the given frame.
        /// @par May be used externally to animate the light's color/attenuation properties,
        /// and is used internally to synchronize the light's position with the position of the LightSource.
        osg::Light* getLight(unsigned int frame)
        {
            return mLight[frame % 2];
        }

        /// @warning It is recommended not to replace an existing osg::Light, because there might still be
        /// references to it in the light StateSet cache that are associated with this LightSource's ID.
        /// These references will stay valid due to ref_ptr but will point to the old object.
        /// @warning Do not modify the \a light after you've called this function.
        void setLight(osg::Light* light)
        {
            mLight[0] = light;
            mLight[1] = new osg::Light(*light);
        }

        /// Get the unique ID for this light source.
        int getId() const
        {
            return mId;
        }
    };

    /// @brief Decorator node implementing the rendering of any number of LightSources that can be anywhere in the subgraph.
    class LightManager : public osg::Group
    {
    public:

        META_Node(SceneUtil, LightManager)

        LightManager();

        LightManager(const LightManager& copy, const osg::CopyOp& copyop);

        /// @param mask This mask is compared with the current Camera's cull mask to determine if lighting is desired.
        /// By default, it's ~0u i.e. always on.
        /// If you have some views that do not require lighting, then set the Camera's cull mask to not include
        /// the lightingMask for a much faster cull and rendering.
        void setLightingMask (unsigned int mask);

        unsigned int getLightingMask() const;

        /// Set the first light index that should be used by this manager, typically the number of directional lights in the scene.
        void setStartLight(int start);

        int getStartLight() const;

        /// Internal use only, called automatically by the LightManager's UpdateCallback
        void update();

        /// Internal use only, called automatically by the LightSource's UpdateCallback
        void addLight(LightSource* lightSource, const osg::Matrixf& worldMat, unsigned int frameNum);

        struct LightSourceTransform
        {
            LightSource* mLightSource;
            osg::Matrixf mWorldMatrix;
        };

        const std::vector<LightSourceTransform>& getLights() const;

        struct LightSourceViewBound
        {
            LightSource* mLightSource;
            osg::BoundingSphere mViewBound;
        };

        const std::vector<LightSourceViewBound>& getLightsInViewSpace(osg::Camera* camera, const osg::RefMatrix* viewMatrix);

        typedef std::vector<const LightSourceViewBound*> LightList;

        /// Spatial grid for fast light candidate lookup.
        /// Lights are placed into 2D cells (XZ plane) based on their view-space position.
        /// Lights with radius > LARGE_LIGHT_THRESHOLD are placed in a separate large-lights list
        /// to guarantee correctness without excessive cell queries.
        struct LightGrid
        {
            static const float CELL_SIZE;
            static const float LARGE_LIGHT_THRESHOLD;

            struct Cell
            {
                std::vector<unsigned int> lightIndices;
            };

            std::unordered_map<uint64_t, Cell> mCells;
            std::vector<unsigned int> mLargeLights;
            bool mBuilt;

            LightGrid() : mBuilt(false) {}

            void clear()
            {
                mCells.clear();
                mLargeLights.clear();
                mBuilt = false;
            }

            /// Build the grid from the given view-space light bounds.
            void build(const std::vector<LightSourceViewBound>& lights)
            {
                clear();
                for (unsigned int i = 0; i < lights.size(); ++i)
                {
                    float radius = lights[i].mLightSource->getRadius();
                    if (radius > LARGE_LIGHT_THRESHOLD)
                    {
                        mLargeLights.push_back(i);
                        continue;
                    }

                    const osg::Vec3f& pos = lights[i].mViewBound.center();
                    int cx = (int)std::floor(pos.x() / CELL_SIZE);
                    int cz = (int)std::floor(pos.z() / CELL_SIZE);

                    // Light may overlap into neighboring cells
                    int cellSpan = (int)std::ceil(radius / CELL_SIZE);
                    for (int dx = -cellSpan; dx <= cellSpan; ++dx)
                        for (int dz = -cellSpan; dz <= cellSpan; ++dz)
                            mCells[packCell(cx + dx, cz + dz)].lightIndices.push_back(i);
                }
                mBuilt = true;
            }

            /// Query the grid with an object's view-space bounding sphere.
            /// @param outIndices Receives the candidate light indices, sorted and without duplicates.
            void query(const osg::BoundingSphere& bound, std::vector<unsigned int>& outIndices) const
            {
                outIndices.clear();
                const osg::Vec3f& center = bound.center();
                float radius = bound.radius();

                int cx = (int)std::floor(center.x() / CELL_SIZE);
                int cz = (int)std::floor(center.z() / CELL_SIZE);

                // Check enough cells to cover the object radius plus the max gridded light radius
                int range = (int)std::ceil((radius + LARGE_LIGHT_THRESHOLD) / CELL_SIZE);
                for (int dx = -range; dx <= range; ++dx)
                    for (int dz = -range; dz <= range; ++dz)
                    {
                        auto it = mCells.find(packCell(cx + dx, cz + dz));
                        if (it != mCells.end())
                        {
                            const std::vector<unsigned int>& indices = it->second.lightIndices;
                            outIndices.insert(outIndices.end(), indices.begin(), indices.end());
                        }
                    }

                // Always check large lights
                outIndices.insert(outIndices.end(), mLargeLights.begin(), mLargeLights.end());

                // A light may overlap several cells, so drop duplicate indices.
                // Sorting also restores the order in which the lights were collected.
                std::sort(outIndices.begin(), outIndices.end());
                outIndices.erase(std::unique(outIndices.begin(), outIndices.end()), outIndices.end());
            }

        private:
            static uint64_t packCell(int x, int z)
            {
                return ((uint64_t)(unsigned int)x << 32) | (unsigned int)z;
            }
        };

        /// Get the view-space spatial grid for lights. Built lazily per camera per frame.
        const LightGrid& getLightGrid(osg::Camera* camera, const std::vector<LightSourceViewBound>& viewSpaceLights);

        osg::ref_ptr<osg::StateSet> getLightListStateSet(const LightList& lightList, unsigned int frameNum);

    private:
        // Lights collected from the scene graph. Only valid during the cull traversal.
        std::vector<LightSourceTransform> mLights;

        // iOS optimization: single-camera cache instead of std::map lookup.
        // OpenMW iOS uses one primary camera, so map overhead is unnecessary.
        typedef std::vector<LightSourceViewBound> LightSourceViewBoundCollection;
        osg::Camera* mCachedViewSpaceCamera;
        LightSourceViewBoundCollection mLightsInViewSpace;

        // Spatial grid of the lights in view space, used to quickly find the lights affecting an object.
        // Rebuilt lazily whenever the camera changes or the lights are updated.
        LightGrid mLightGrid;
        osg::observer_ptr<osg::Camera> mLightGridCamera;

        // < Light list hash , StateSet >
        typedef std::unordered_map<size_t, osg::ref_ptr<osg::StateSet> > LightStateSetMap;
        LightStateSetMap mStateSetCache[2];

        std::vector<osg::ref_ptr<osg::StateAttribute>> mDummies;

        int mStartLight;

        unsigned int mLightingMask;
    };

    /// To receive lighting, objects must be decorated by a LightListCallback. Light list callbacks must be added via
    /// node->addCullCallback(new LightListCallback). Once a light list callback is added to a node, that node and all
    /// its child nodes can receive lighting.
    /// @par The placement of these LightListCallbacks affects the granularity of light lists. Having too fine grained
    /// light lists can result in degraded performance. Too coarse grained light lists can result in lights no longer
    /// rendering when the size of a light list exceeds the OpenGL limit on the number of concurrent lights (8). A good
    /// starting point is to attach a LightListCallback to each game object's base node.
    /// @note Not thread safe for CullThreadPerCamera threading mode.
    /// @note Due to lack of OSG support, the callback does not work on Drawables.
    class LightListCallback : public osg::NodeCallback
    {
    public:
        LightListCallback()
            : mLightManager(nullptr)
            , mLastFrameNumber(0)
        {}
        LightListCallback(const LightListCallback& copy, const osg::CopyOp& copyop)
            : osg::Object(copy, copyop), osg::NodeCallback(copy, copyop)
            , mLightManager(copy.mLightManager)
            , mLastFrameNumber(0)
            , mIgnoredLightSources(copy.mIgnoredLightSources)
        {}

        META_Object(SceneUtil, LightListCallback)

        void operator()(osg::Node* node, osg::NodeVisitor* nv);

        bool pushLightState(osg::Node* node, osgUtil::CullVisitor* nv);

        std::set<SceneUtil::LightSource*>& getIgnoredLightSources() { return mIgnoredLightSources; }

    private:
        LightManager* mLightManager;
        unsigned int mLastFrameNumber;
        LightManager::LightList mLightList;
        std::set<SceneUtil::LightSource*> mIgnoredLightSources;
    };

}

#endif
