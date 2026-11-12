QMLTESTRUNNER ?= /usr/lib/qt6/bin/qmltestrunner
TEST_INPUT ?= tests

.PHONY: test test-wayland

test:
	QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software $(QMLTESTRUNNER) -input $(TEST_INPUT)

test-wayland:
	QT_QUICK_BACKEND=rhi QSG_RHI_BACKEND=opengl $(QMLTESTRUNNER) -platform wayland -input $(TEST_INPUT)
