from setuptools import setup, find_packages

setup(
    name="ollama-vibe",
    version="0.1.0",
    packages=find_packages(),
    install_requires=[],
    entry_points={
        'console_scripts': [
            'ollama-vibe=ollama_vibe.cli:main',
        ],
    },
)
