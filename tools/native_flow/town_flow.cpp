#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2i.hpp>

#include <algorithm>
#include <cstdint>
#include <limits>
#include <queue>
#include <vector>

using namespace godot;

namespace {
constexpr int32_t unreachable = std::numeric_limits<int32_t>::max();
constexpr uint8_t no_direction = 255;
constexpr int dx[] = {0, 1, 1, 1, 0, -1, -1, -1};
constexpr int dy[] = {-1, -1, 0, 1, 1, 1, 0, -1};

struct Entry {
    int32_t cell;
    int32_t distance;
    int64_t order;
};

struct Later {
    bool operator()(const Entry &a, const Entry &b) const {
        if (a.distance != b.distance) {
            return a.distance > b.distance;
        }
        return a.order > b.order;
    }
};

class TownFlowNative : public RefCounted {
    GDCLASS(TownFlowNative, RefCounted)

protected:
    static void _bind_methods() {
        ClassDB::bind_static_method("TownFlowNative",
            D_METHOD("build_field", "cost", "size", "goals", "physical"),
            &TownFlowNative::build_field);
    }

public:
    static Array build_field(const PackedInt32Array &cost, Vector2i size,
            const PackedInt32Array &goals, const PackedInt32Array &physical) {
        const int64_t count = int64_t(size.x) * size.y;
        if (size.x <= 0 || size.y <= 0 || count >= unreachable ||
                cost.size() != count || physical.size() != count) {
            return {};
        }

        PackedInt32Array integration;
        PackedByteArray direction;
        if (integration.resize(count) != OK || direction.resize(count) != OK) {
            return {};
        }
        auto *distance = integration.ptrw();
        auto *heading = direction.ptrw();
        std::fill_n(distance, count, unreachable);
        std::fill_n(heading, count, no_direction);
        const auto *weights = cost.ptr();
        const auto *terrain = physical.ptr();
        std::priority_queue<Entry, std::vector<Entry>, Later> frontier;
        int64_t order = 0;
        for (int64_t i = 0; i < goals.size(); ++i) {
            const int32_t cell = goals[i];
            if (cell < 0 || cell >= count) {
                return {};
            }
            if (distance[cell] != 0) {
                distance[cell] = 0;
                frontier.push({cell, 0, order++});
            }
        }

        // FIFO tie-breaking matches the GDScript bucket queue, including at gates.
        while (!frontier.empty()) {
            const Entry cur = frontier.top();
            frontier.pop();
            if (distance[cur.cell] != cur.distance) {
                continue;
            }
            const int x = cur.cell % size.x;
            const int y = cur.cell / size.x;
            for (int d = 0; d < 8; ++d) {
                const int nx = x + dx[d];
                const int ny = y + dy[d];
                if (nx < 0 || nx >= size.x || ny < 0 || ny >= size.y) {
                    continue;
                }
                const int32_t neighbor = ny * size.x + nx;
                if (weights[neighbor] <= 0) {
                    continue;
                }
                const bool diagonal = (d & 1) != 0;
                if (diagonal && (terrain[y * size.x + nx] <= 0 || terrain[ny * size.x + x] <= 0)) {
                    continue;
                }
                const int64_t next = cur.distance + int64_t(weights[neighbor]) * (diagonal ? 14 : 10);
                if (next < distance[neighbor]) {
                    distance[neighbor] = static_cast<int32_t>(next);
                    heading[neighbor] = (d + 4) & 7;
                    frontier.push({neighbor, distance[neighbor], order++});
                }
            }
        }
        return Array::make(integration, direction);
    }
};

void initialize(ModuleInitializationLevel level) {
    if (level == MODULE_INITIALIZATION_LEVEL_SCENE) {
        ClassDB::register_abstract_class<TownFlowNative>();
    }
}

void terminate(ModuleInitializationLevel) {}
} // namespace

extern "C" GDExtensionBool GDE_EXPORT town_flow_init(
        GDExtensionInterfaceGetProcAddress get_proc_address,
        GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
    init.register_initializer(initialize);
    init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
    return init.init();
}
