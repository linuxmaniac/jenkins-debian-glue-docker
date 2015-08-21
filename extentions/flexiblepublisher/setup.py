#!/usr/bin/env python
import setuptools

setuptools.setup(
    name='flexible-publish',
    packages=['flexible_publish'],
    entry_points={
        'jenkins_jobs.publishers': [
            'flexible-publish=flexible_publish.publisher:flexible_publisher'
        ],
    })
