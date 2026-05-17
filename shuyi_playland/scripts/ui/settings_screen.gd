extends Control

@onready var sound_toggle: CheckBox = %SoundToggle
@onready var animation_toggle: CheckBox = %AnimationToggle
@onready var eye_care_toggle: CheckBox = %EyeCareToggle
@onready var eye_care_slider: HSlider = %EyeCareSlider
@onready var backup_label: Label = %BackupLabel
@onready var export_button: Button = %ExportButton
@onready var import_button: Button = %ImportButton
@onready var version_label: Label = %VersionLabel
@onready var help_label: RichTextLabel = %HelpLabel


func _ready() -> void:
	refresh_view()
	sound_toggle.toggled.connect(func(enabled: bool) -> void: AppState.update_setting("sound_enabled", enabled))
	animation_toggle.toggled.connect(func(enabled: bool) -> void: AppState.update_setting("animation_enabled", enabled))
	eye_care_toggle.toggled.connect(func(enabled: bool) -> void: AppState.update_setting("eye_care_enabled", enabled))
	eye_care_slider.value_changed.connect(func(value: float) -> void: AppState.update_setting("eye_care_minutes", int(value)))
	export_button.pressed.connect(_on_export_pressed)
	import_button.pressed.connect(_on_import_pressed)
	AppState.state_changed.connect(func() -> void: refresh_view())


func refresh_view() -> void:
	var settings: Dictionary = AppState.get_settings()
	sound_toggle.button_pressed = settings.get("sound_enabled", true)
	animation_toggle.button_pressed = settings.get("animation_enabled", true)
	eye_care_toggle.button_pressed = settings.get("eye_care_enabled", true)
	eye_care_slider.value = float(settings.get("eye_care_minutes", 20))
	version_label.text = "版本：%s\n备份：ZIP + JSON + SQLite 快照\n护眼提醒：每 %d 分钟一次" % [AppState.get_save_overview().get("version", "0.5.0-expanded"), int(settings.get("eye_care_minutes", 20))]
	help_label.text = "[b]使用帮助[/b]\n• 首页可进入关卡闯关、专项练习、随机练习、模拟测试。\n• 成长中心可查看并领取任务与成就奖励。\n• 错题本可发起错题重练。\n• 小游戏入口位于主导航。\n• 备份会导出 ZIP，包含 JSON 存档和 SQLite 快照。"
	backup_label.text = "护眼提示：%s" % AppState.save_data.get("meta", {}).get("eye_care_tip", "请及时休息")


func _on_export_pressed() -> void:
	var result: Dictionary = BackupService.export_backup()
	backup_label.text = result.get("message", "导出完成。")


func _on_import_pressed() -> void:
	var result: Dictionary = BackupService.import_backup()
	backup_label.text = result.get("message", "导入完成。")
