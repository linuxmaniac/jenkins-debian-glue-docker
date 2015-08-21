import xml.etree.ElementTree as XML


def flexible_publisher(parser, xml_parent, data):
    """yaml: flexible-publish
    Support flexible publish features.
    Requires the Jenkins `Flexible Publish Plugin
    <https://wiki.jenkins-ci.org/display/JENKINS/Flexible+Publish+Plugin>`
    as well as Jenkins `Run Condition Plugin
    <https://wiki.jenkins-ci.org/display/JENKINS/Run+Condition+Plugin>`
    and Jenkins `Parameterized Trigger Plugin
    <https://wiki.jenkins-ci.org/display/JENKINS/Parameterized+Trigger+Plugin>`

    :arg str expression: the regular expression used to match the label
    :arg str label: the label that will be tested by the regular expression
    :arg str properties: predefined parameters that should be passed
    :arg str projects: comma separated list of projects that should be
                       triggered
    :arg str condition: determines for which results of the current build, the
                        new build(s) will be triggered (SUCCESS, UNSTABLE,...)
    :arg str trigger-with-no-parameters: trigger a build even when there are
                        currently no parameters defined? (true | false)

    NOTE: this extension does NOT implement all the functionality provided by
    the Jenkins Flexible Publish Plugin, but is restricted to the
    features and configuration as present in Sipwise' Jenkins environment
    (being a "Regular expression match" run provided via Run Condition Plugin)
    and "Trigger parameterized build other projects" action provided via
    Parameterized Trigger Plugin and its relevant configuration).

    Known TODOs:
    - move from "properties" to predefined-parameters or similar and support
      multiple lines

    Example:

    publishers:
      - flexible-publish:
          expression: '^release-mr\d\.\d.*-update$'
          label: '$release'
          properties: 'release=$release'
          projects: 'release-update, '
          condition: SUCCESS
          trigger-with-no-parameters: 'false'
    """
    CLASS = [
        'org.jenkins__ci.plugins.flexible__publish.FlexiblePublisher',
        'org.jenkins__ci.plugins.flexible__publish.ConditionalPublisher',
        'org.jenkins_ci.plugins.run_condition.core.ExpressionCondition',
        'hudson.plugins.parameterizedtrigger.BuildTrigger',
        'hudson.plugins.parameterizedtrigger.BuildTriggerConfig',
        'hudson.plugins.parameterizedtrigger.PredefinedBuildParameters',
    ]
    flexpub = XML.SubElement(xml_parent, CLASS[0])
    publishers = XML.SubElement(flexpub, 'publishers')
    conditionalpublisher = XML.SubElement(publishers, CLASS[1])
    expressioncondition = XML.SubElement(conditionalpublisher, 'condition',
                                         {'class': CLASS[2]})
    XML.SubElement(expressioncondition, 'expression').text = data['expression']
    XML.SubElement(expressioncondition, 'label').text = data['label']

    publisher = XML.SubElement(conditionalpublisher, 'publisher',
                               {'class': CLASS[3]})
    publisher_configs = XML.SubElement(publisher, 'configs')
    buildtrigger_config = XML.SubElement(publisher_configs, CLASS[4])
    predefinedbuildparamters_config = XML.SubElement(
        buildtrigger_config, 'configs')
    predefinedbuildparamters = XML.SubElement(predefinedbuildparamters_config,
                                              CLASS[5])
    XML.SubElement(predefinedbuildparamters, 'properties').text = data[
        'properties']
    XML.SubElement(buildtrigger_config, 'projects').text = data['projects']
    XML.SubElement(buildtrigger_config, 'condition').text = data['condition']
    XML.SubElement(buildtrigger_config, 'triggerWithNoParameters').text = data[
        'trigger-with-no-parameters']
