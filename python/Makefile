PLATFORMS := macosx_11_0_intel macosx_11_0_x86_64 macosx_11_0_arm64 manylinux2014_x86_64 manylinux_2_27_x86_64 manylinux2014_aarch64 manylinux_2_27_aarch64 win32 win_amd64

dist:
	rm -rf build
	rm -rf dist
	rm -rf kcl_lib.egg-info
	rm -rf kcl_lib/lib/**
	for platform in $(PLATFORMS); do \
		rm -rf build && rm -rf kcl_lib/lib && python3 setup.py bdist_wheel --plat-name $$platform; \
	done
	python3 -m twine upload dist/kcl_lib-*

fmt:
	python3 -m black .
