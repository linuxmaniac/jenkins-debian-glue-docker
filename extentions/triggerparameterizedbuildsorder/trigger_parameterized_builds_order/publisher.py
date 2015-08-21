import xml.etree.ElementTree as XML


def trigger_parameterized_builds_order(parser, xml_parent, data):
    """yaml: trigger-parameterized-builds
    Trigger parameterized builds of other jobs.
    Requires the Jenkins `Parameterized Trigger Plugin.
    <https://wiki.jenkins-ci.org/display/JENKINS/
    Parameterized+Trigger+Plugin>`_

    Use of the `node-label-name` or `node-label` parameters
    requires the Jenkins `NodeLabel Parameter Plugin.
    <https://wiki.jenkins-ci.org/display/JENKINS/NodeLabel+Parameter+P
    lugin>`_

    :arg str project: name of the job to trigger
    :arg str predefined-parameters: parameters to pass to the other
      job (optional)
    :arg bool current-parameters: Whether to include the parameters passed
      to the current build to the triggered job (optional)
    :arg bool svn-revision: Pass svn revision to the triggered job (optional)
    :arg bool git-revision: Pass git revision to the other job (optional)
    :arg str condition: when to trigger the other job (default 'ALWAYS')
    :arg str property-file: Use properties from file (optional)
    :arg bool fail-on-missing: Blocks the triggering of the downstream jobs
      if any of the files are not found in the workspace (default 'False')
    :arg str restrict-matrix-project: Filter that restricts the subset
        of the combinations that the downstream project will run (optional)
    :arg str node-label-name: Specify the Name for the NodeLabel parameter.
      (optional)
    :arg str node-label: Specify the Node for the NodeLabel parameter.
      (optional)
    :arg str order: coma separated list of parameters

    Example:

    .. literalinclude::
      /../../tests/publishers/fixtures/trigger_parameterized_builds003.yaml

    """
    allowed_keys = [
        'predefined-parameters',
        'git-revision',
        'property-file',
        'current-parameters',
        'svn-revision',
        'restrict-matrix-project',
        'node-label-name',
        'node-label',
    ]

    def _has_allowed(keys):
        for k in keys:
            if k in allowed_keys:
                return True
        return False

    def _add(key, tconfigs, project_def):
        if key == 'predefined-parameters':
            params = XML.SubElement(tconfigs,
                                    'hudson.plugins.parameterizedtrigger.'
                                    'PredefinedBuildParameters')
            properties = XML.SubElement(params, 'properties')
            properties.text = project_def['predefined-parameters']
        elif key == 'git-revision':
            params = XML.SubElement(tconfigs,
                                    'hudson.plugins.git.'
                                    'GitRevisionBuildParameters')
            properties = XML.SubElement(params, 'combineQueuedCommits')
            properties.text = 'false'
        elif key == 'property-file':
            params = XML.SubElement(tconfigs,
                                    'hudson.plugins.parameterizedtrigger.'
                                    'FileBuildParameters')
            properties = XML.SubElement(params, 'propertiesFile')
            properties.text = project_def['property-file']
            failOnMissing = XML.SubElement(params, 'failTriggerOnMissing')
            failOnMissing.text = str(project_def.get('fail-on-missing',
                                                     False)).lower()
        elif key == 'current-parameters':
            XML.SubElement(tconfigs,
                           'hudson.plugins.parameterizedtrigger.'
                           'CurrentBuildParameters')
        elif key == 'svn-revision':
            XML.SubElement(tconfigs,
                           'hudson.plugins.parameterizedtrigger.'
                           'SubversionRevisionBuildParameters')
        elif key == 'restrict-matrix-project':
            subset = XML.SubElement(tconfigs,
                                    'hudson.plugins.parameterizedtrigger.'
                                    'matrix.MatrixSubsetBuildParameters')
            XML.SubElement(subset, 'filter').text = \
                project_def['restrict-matrix-project']
        elif key in ['node-label', 'node-label-name']:
            params = XML.SubElement(tconfigs,
                                    'org.jvnet.jenkins.plugins.'
                                    'nodelabelparameter.'
                                    'parameterizedtrigger.'
                                    'NodeLabelBuildParameter')
            name = XML.SubElement(params, 'name')
            if 'node-label-name' in project_def:
                name.text = project_def['node-label-name']
            label = XML.SubElement(params, 'nodeLabel')
            if 'node-label' in project_def:
                label.text = project_def['node-label']
        else:
            raise JenkinsJobsException(
                'trigger_parameterized_builds must be one of: '
                + ', '.join(allowed_keys) + ' key: ' + key)

    tbuilder = XML.SubElement(xml_parent,
                              'hudson.plugins.parameterizedtrigger.'
                              'BuildTrigger')
    configs = XML.SubElement(tbuilder, 'configs')
    for project_def in data:
        tconfig = XML.SubElement(configs,
                                 'hudson.plugins.parameterizedtrigger.'
                                 'BuildTriggerConfig')
        tconfigs = XML.SubElement(tconfig, 'configs')
        order = project_def.pop('order', [])
        if (_has_allowed(project_def.iterkeys())):
            if 'predefined-parameters' in project_def \
                    and 'predefined-parameters' not in order:
                _add('predefined-parameters', tconfigs, project_def)
            if 'git-revision' in project_def and project_def['git-revision'] \
                    and 'git-revision' not in order:
                _add('git-revision', tconfigs, project_def)
            if 'property-file' in project_def \
                    and project_def['property-file'] \
                    and 'property-file' not in order:
                _add('property-file', tconfigs, project_def)
            if 'current-parameters' in project_def \
                    and project_def['current-parameters'] \
                    and 'current-parameters' not in order:
                _add('current-parameters', tconfigs, project_def)
            if 'svn-revision' in project_def and project_def['svn-revision'] \
                    and 'svn-revision' not in order:
                _add('svn-revision', tconfigs, project_def)
            if 'restrict-matrix-project' in project_def \
                    and project_def['restrict-matrix-project'] \
                    and 'restrict-matrix-project' not in order:
                _add('restrict-matrix-project', tconfigs, project_def)
            if ('node-label-name' in project_def or
                    'node-label' in project_def) and \
                    ('node-label-name' not in order and
                        'node-label' not in order):
                _add('node-label', tconfigs, project_def)
        else:
            tconfigs.set('class', 'java.util.Collections$EmptyList')
        if order:
            order_list = order.split(',')
            if 'node-label' in order_list and 'node-label-name' in order_list:
                order_list.remove('node-label-name')
            for p in order_list:
                _add(p.strip(), tconfigs, project_def)
        projects = XML.SubElement(tconfig, 'projects')
        projects.text = project_def['project']
        condition = XML.SubElement(tconfig, 'condition')
        condition.text = project_def.get('condition', 'ALWAYS')
        trigger_with_no_params = XML.SubElement(tconfig,
                                                'triggerWithNoParameters')
        trigger_with_no_params.text = 'false'
