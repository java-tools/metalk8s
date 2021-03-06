beforeEach(() => {
  cy.setupMocks();
  cy.login();
});

// Navigation tests
describe('Volume list', () => {
  it('brings me to the overview tab of the unhealthy volume', () => {
    // Note that:
    // If we visit() in beforeEach, make sure we don't visit() again within each test case, or it may create issues with the test
    // (some network requests would be interrupted) - see 07a34b5 (#2891)
    cy.visit('/volumes');
    cy.stubHistory();

    // Volume `master-0-alertmanager` has alert.
    // According to the default sorting rule, it should appear at the first place.
    cy.location('pathname').should(
      'eq',
      '/volumes/master-0-alertmanager/overview',
    );
  });

  it('brings me to the overview tab of master-0-alertmanager Volume', () => {
    cy.visit('/volumes');
    cy.stubHistory();

    cy.get('[data-cy="volume_table_name_cell"]')
      .contains('master-1-prometheus')
      .click();
    cy.get('@historyPush').should('be.calledWithExactly', {
      pathname: '/volumes/master-1-prometheus/overview',
      search: '',
    });
  });

  it('brings me to another volume with the same tab selected and queryString kept', () => {
    cy.visit('/volumes/master-1-prometheus/metrics?from=now-7d');
    cy.stubHistory();

    cy.get('[data-cy="volume_table_name_cell"]')
      .contains('prom-m0-reldev')
      .click();
    cy.get('@historyPush').should('be.calledOnce').and('be.calledWithExactly', {
      pathname: '/volumes/prom-m0-reldev/metrics',
      search: 'from=now-7d',
    });
  });

  it('brings me to create volume page', () => {
    cy.visit('/volumes');
    cy.stubHistory();

    cy.get('[data-cy="create_volume_button"]').click();
    cy.get('@historyPush').and('be.calledWithExactly', '/volumes/createVolume');
  });

  it('updates url with the search', () => {
    cy.visit('/volumes');
    cy.stubHistory();

    cy.get('[data-cy="volume_list_search"]').type('hello');
    cy.get('@historyPush').and('be.calledWithExactly', '?search=hello');
  });

  it(`keeps warning severity for the alert while searching the node`, () => {
    cy.visit('/volumes/master-1-prometheus/alerts?severity=warning');
    cy.stubHistory();

    cy.get('[data-cy="volume_list_search"]').type('hello');
    cy.get('@historyPush').should(
      'be.calledWithExactly',
      '?severity=warning&search=hello',
    );
  });
});
