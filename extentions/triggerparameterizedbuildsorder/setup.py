#!/usr/bin/env python
import setuptools

setuptools.setup(
    name='trigger-parameterized-builds-order',
    packages=['trigger_parameterized_builds_order'],
    entry_points={
        'jenkins_jobs.publishers': [
            'trigger-parameterized-builds-order='
            'trigger_parameterized_builds_order.publisher:'
            'trigger_parameterized_builds_order'
        ],
    })
