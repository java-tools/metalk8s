import React from 'react';
import { connect } from 'react-redux';
import styled from 'styled-components';
import { Formik, Form } from 'formik';
import * as Yup from 'yup';
import { withRouter } from 'react-router-dom';
import { injectIntl } from 'react-intl';
import { Button, Input } from 'core-ui';
import { padding, brand } from 'core-ui/dist/style/theme';
import { isEmpty } from 'lodash';
import {
  createNodeAction,
  clearCreateNodeErrorAction
} from '../ducks/app/nodes';

const CreateNodeLayout = styled.div`
  height: 100%;
  overflow: auto;
  padding: ${padding.larger};
  form {
    width: 450px;
    padding: 0 ${padding.larger};
    .sc-input {
      margin: ${padding.smaller} 0;
      .sc-input-label {
        width: 200px;
      }
    }
  }
`;

const PageHeader = styled.h2`
  margin-top: 0;
`;

const ActionContainer = styled.div`
  display: flex;
  margin: ${padding.larger} 0;
  justify-content: flex-end;

  button {
    margin-right: ${padding.larger};
  }
`;

const ErrorMessage = styled.span`
  margin-top: ${padding.base};
  color: ${brand.danger};
`;

const FormTitle = styled.h3`
  margin-top: ${padding.larger};
`;

const initialValues = {
  name: '',
  ssh_user: '',
  hostName_ip: '',
  ssh_port: '',
  ssh_key_path: '',
  sudo_required: false,
  workload_plane: true,
  control_plane: false
};

const validationSchema = Yup.object().shape({
  name: Yup.string().required(),
  ssh_user: Yup.string().required(),
  hostName_ip: Yup.string().required(),
  ssh_port: Yup.string().required(),
  ssh_key_path: Yup.string().required(),
  sudo_required: Yup.boolean().required(),
  workload_plane: Yup.boolean().required(),
  control_plane: Yup.boolean().required()
});

class NodeCreateForm extends React.Component {
  componentWillUnmount() {
    this.props.clearCreateNodeError();
  }

  render() {
    const { intl, asyncErrors } = this.props;
    return (
      <CreateNodeLayout>
        <PageHeader>{intl.messages.create_new_node}</PageHeader>
        <Formik
          initialValues={initialValues}
          validationSchema={validationSchema}
          onSubmit={this.props.createNode}
        >
          {props => {
            const {
              values,
              touched,
              errors,
              dirty,
              setFieldTouched,
              setFieldValue
            } = props;

            //handleChange of the Formik props does not update 'values' when field value is empty
            const handleChange = (e, field) => {
              const { value, checked, type } = e.target;
              setFieldValue(field, type === 'checkbox' ? checked : value, true);
            };
            //touched is not "always" correctly set
            const handleOnBlur = e => setFieldTouched(e.target.name, true);

            return (
              <Form>
                <Input
                  name="name"
                  label={intl.messages.name}
                  value={values.name}
                  onChange={e => handleChange(e, 'name')}
                  error={touched.name && errors.name}
                  onBlur={handleOnBlur}
                />
                <Input
                  name="ssh_user"
                  label={intl.messages.ssh_user}
                  value={values.ssh_user}
                  onChange={e => handleChange(e, 'ssh_user')}
                  error={touched.ssh_user && errors.ssh_user}
                  onBlur={handleOnBlur}
                />
                <Input
                  name="hostName_ip"
                  label={intl.messages.hostName_ip}
                  value={values.hostName_ip}
                  onChange={e => handleChange(e, 'hostName_ip')}
                  error={touched.hostName_ip && errors.hostName_ip}
                  onBlur={handleOnBlur}
                />
                <Input
                  name="ssh_port"
                  label={intl.messages.ssh_port}
                  value={values.ssh_port}
                  onChange={e => handleChange(e, 'ssh_port')}
                  error={touched.ssh_port && errors.ssh_port}
                  onBlur={handleOnBlur}
                />
                <Input
                  name="ssh_key_path"
                  label={intl.messages.ssh_key_path}
                  value={values.ssh_key_path}
                  onChange={e => handleChange(e, 'ssh_key_path')}
                  error={touched.ssh_key_path && errors.ssh_key_path}
                  onBlur={handleOnBlur}
                />
                <Input
                  name="sudo_required"
                  type="checkbox"
                  label={intl.messages.sudo_required}
                  value={values.sudo_required}
                  checked={values.sudo_required}
                  onChange={e => handleChange(e, 'sudo_required')}
                  onBlur={handleOnBlur}
                />
                <FormTitle>{intl.messages.roles}</FormTitle>
                <Input
                  type="checkbox"
                  name="workload_plane"
                  label={intl.messages.workload_plane}
                  checked={values.workload_plane}
                  value={values.workload_plane}
                  onChange={e => handleChange(e, 'workload_plane')}
                  onBlur={handleOnBlur}
                  error={
                    values.workload_plane || values.control_plane
                      ? ''
                      : intl.messages.role_values_error
                  }
                />
                <Input
                  type="checkbox"
                  name="control_plane"
                  label={intl.messages.control_plane}
                  checked={values.control_plane}
                  value={values.control_plane}
                  onChange={e => handleChange(e, 'control_plane')}
                  onBlur={handleOnBlur}
                  error={
                    values.workload_plane || values.control_plane
                      ? ''
                      : intl.messages.role_values_error
                  }
                />
                <ActionContainer>
                  <Button
                    text={intl.messages.cancel}
                    type="button"
                    outlined
                    onClick={() => this.props.history.push('/nodes')}
                  />
                  <Button
                    text={intl.messages.create}
                    type="submit"
                    disabled={
                      !dirty ||
                      !isEmpty(errors) ||
                      !(values.workload_plane || values.control_plane)
                    }
                  />
                </ActionContainer>
                {asyncErrors && asyncErrors.create_node ? (
                  <ErrorMessage>{asyncErrors.create_node}</ErrorMessage>
                ) : null}
              </Form>
            );
          }}
        </Formik>
      </CreateNodeLayout>
    );
  }
}

const mapStateToProps = state => ({
  asyncErrors: state.app.nodes.errors
});

const mapDispatchToProps = dispatch => {
  return {
    createNode: body => dispatch(createNodeAction(body)),
    clearCreateNodeError: () => dispatch(clearCreateNodeErrorAction())
  };
};

export default injectIntl(
  withRouter(
    connect(
      mapStateToProps,
      mapDispatchToProps
    )(NodeCreateForm)
  )
);
