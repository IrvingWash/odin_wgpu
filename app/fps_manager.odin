package app

@(require) import "core:log"
import "core:time"

@(private = "file")
FPS_Manager :: struct {
	prev_time:      time.Time,
	time_per_frame: time.Duration,
}

@(private = "file")
fps_manager := FPS_Manager{}

fps_manager_init :: proc(target_fps: u64) {
	fps_manager.time_per_frame = time.Duration(time.Second / auto_cast target_fps)
	fps_manager.prev_time = time.now()
}

cap_fps :: proc() {
	current_time := time.now()

	time_to_sleep := fps_manager.time_per_frame - time.diff(fps_manager.prev_time, current_time)

	when ODIN_DEBUG {
		log.info(time_to_sleep)
	}

	if time_to_sleep > 0 {
		time.sleep(time_to_sleep)
	}

	fps_manager.prev_time = time.now()
}

