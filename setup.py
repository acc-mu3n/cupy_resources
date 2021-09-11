#!/usr/bin/env python

import glob
import os
from setuptools import setup, find_packages
import sys

source_root = os.path.abspath(os.path.dirname(__file__))
sys.path.append(os.path.join(source_root, 'install'))

import cupy_builder  # NOQA
from cupy_builder import cupy_setup_build  # NOQA

ctx = cupy_builder.Context(source_root)
cupy_builder.initialize(ctx)
if not cupy_builder.preflight_check(ctx):
    sys.exit(1)


# TODO(kmaehashi): migrate to pyproject.toml (see #4727, #4619)
setup_requires = [
    'Cython>=0.29.22,<3',
    'fastrlock>=0.5',
]
install_requires = [
    'numpy>=1.17,<1.24',  # see #4773
    'fastrlock>=0.5',
]
extras_require = {
    'all': [
        'scipy>=1.4,<1.10',  # see #4773
        'Cython>=0.29.22,<3',
        'optuna>=2.0',
    ],
    'stylecheck': [
        'autopep8==1.5.5',
        'flake8==3.8.4',
        'pbr==5.5.1',
        'pycodestyle==2.6.0',
    ],
    'test': [
        # 4.2 <= pytest < 6.2 is slow collecting tests and times out on CI.
        'pytest>=6.2',
    ],
    # TODO(kmaehashi): Remove 'jenkins' requirements.
    'jenkins': [
        'pytest>=6.2',
        'pytest-timeout',
        'pytest-cov',
        'coveralls',
        'codecov',
        'coverage<5',  # Otherwise, Python must be built with sqlite
    ],
}
tests_require = extras_require['test']


# List of files that needs to be in the distribution (sdist/wheel).
# Notes:
# - Files only needed in sdist should be added to `MANIFEST.in`.
# - The following glob (`**`) ignores items starting with `.`.
cupy_package_data = [
    'cupy/cuda/cupy_thrust.cu',
    'cupy/cuda/cupy_cub.cu',
    'cupy/cuda/cupy_cufftXt.cu',  # for cuFFT callback
    'cupy/cuda/cupy_cufftXt.h',  # for cuFFT callback
    'cupy/cuda/cupy_cufft.h',  # for cuFFT callback
    'cupy/cuda/cufft.pxd',  # for cuFFT callback
    'cupy/cuda/cufft.pyx',  # for cuFFT callback
    'cupy/random/cupy_distributions.cu',
    'cupy/random/cupy_distributions.cuh',
] + [
    x for x in glob.glob('cupy/_core/include/cupy/**', recursive=True)
    if os.path.isfile(x)
]

package_data = {
    'cupy': [
        os.path.relpath(x, 'cupy') for x in cupy_package_data
    ],
}

package_data['cupy'] += cupy_setup_build.prepare_wheel_libs()

package_name = cupy_setup_build.get_package_name()
long_description = cupy_setup_build.get_long_description()
ext_modules = cupy_setup_build.get_ext_modules()
build_ext = cupy_setup_build.custom_build_ext

here = os.path.abspath(os.path.dirname(__file__))
# Get __version__ variable
with open(os.path.join(here, 'cupy', '_version.py')) as f:
    exec(f.read())

CLASSIFIERS = """\
Development Status :: 5 - Production/Stable
Intended Audience :: Science/Research
Intended Audience :: Developers
License :: OSI Approved :: MIT License
Programming Language :: Python
Programming Language :: Python :: 3
Programming Language :: Python :: 3.6
Programming Language :: Python :: 3.7
Programming Language :: Python :: 3.8
Programming Language :: Python :: 3.9
Programming Language :: Python :: 3 :: Only
Programming Language :: Cython
Topic :: Software Development
Topic :: Scientific/Engineering
Operating System :: POSIX
Operating System :: Microsoft :: Windows
"""


setup(
    name=package_name,
    version=__version__,  # NOQA
    description='CuPy: NumPy & SciPy for GPU',
    long_description=long_description,
    author='Seiya Tokui',
    author_email='tokui@preferred.jp',
    url='https://cupy.dev/',
    license='MIT License',
    project_urls={
        "Bug Tracker": "https://github.com/cupy/cupy/issues",
        "Documentation": "https://docs.cupy.dev/",
        "Source Code": "https://github.com/cupy/cupy",
    },
    classifiers=[_f for _f in CLASSIFIERS.split('\n') if _f],
    packages=find_packages(exclude=['install', 'tests']),
    package_data=package_data,
    zip_safe=False,
    python_requires='>=3.6.0',
    setup_requires=setup_requires,
    install_requires=install_requires,
    tests_require=tests_require,
    extras_require=extras_require,
    ext_modules=ext_modules,
    cmdclass={'build_ext': build_ext},
)
