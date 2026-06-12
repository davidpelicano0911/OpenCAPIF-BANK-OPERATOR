
from setuptools import find_packages, setup

NAME = "capif_security"
VERSION = "1.0.0"

# To install the library, run the following
#
# python setup.py install
#
# prerequisite: setuptools
# http://pypi.python.org/pypi/setuptools

REQUIRES = [
    "connexion>=2.0.2",
    "swagger-ui-bundle>=0.0.2",
    "python_dateutil>=2.6.0"
]

setup(
    name=NAME,
    version=VERSION,
    description="CAPIF_Security_API",
    author_email="",
    url="",
    keywords=["OpenAPI", "CAPIF_Security_API"],
    install_requires=REQUIRES,
    packages=find_packages(),
    package_data={'': ['openapi/openapi.yaml']},
    include_package_data=True,
    entry_points={
        'console_scripts': ['capif_security=capif_security.__main__:main']},
    long_description="""\
    API for CAPIF security management.   © 2025, 3GPP Organizational Partners (ARIB, ATIS, CCSA, ETSI, TSDSI, TTA, TTC).   All rights reserved. 
    """
)

