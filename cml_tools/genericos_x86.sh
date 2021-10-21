name: "generic"
hardware: "x86"
version: 1
update_base_url: "file:///tmp/00000000-0000-0000-0000-000000000000/data/guestos_updates/"
init_path: "/sbin/cservice"
init_param: "python3"
init_param: "/app/app.py"
mounts {
	image_file: "root"
	mount_point: "/"
	fs_type: "squashfs"
	mount_type: SHARED_RW
}
mounts {
	image_file: "tmpfs"
	mount_point: "/data/"
	fs_type: "tmpfs"
	mount_type: EMPTY
	def_size: 12
}
description {
	en: "generic GuestOS config (arm)"
}
feature_bg_booting: true
feature_devtmpfs: true