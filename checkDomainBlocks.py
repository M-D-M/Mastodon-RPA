#!/usr/bin/python3

import sys
import requests
import logging
import re
import time
sys.path.append('/var/tmp/share/src')
import ENV
ENV.init('debug')


MASTO_DOMAIN_LIST_SQL = 'SELECT DISTINCT domain FROM accounts;'
MASTO_DOMAIN_BLOCKED_SQL = 'SELECT domain FROM domain_blocks;'
MASTO_API_URL = '/api/v1/instance'
MASTO_ABOUT_REGEX = re.compile('<strong>([^<]*)</strong>.*<span>users',re.DOTALL)
MASTO_USERS_LIMIT = 5000
DOMAIN_CONNECTION_TIMEOUT = (2, 5)
TIME_BETWEEN_REQUESTS = 0.5


def getNumOfUsersFromDomain(the_domain):
    num_of_users = None
    req = None

    # Try to get user count through normal Mastodon API
    try:
        req = requests.get('https://' + the_domain + MASTO_API_URL, timeout=DOMAIN_CONNECTION_TIMEOUT)
    except:
        logging.error('Request for {0} timed out.'.format(the_domain))

    if (req is not None):
        if (req.status_code == 200):
            try:
                json_data = req.json()
                num_of_users = json_data['stats']['user_count']
            except:
                logging.error('Error trying to get json data from response.')
        else:
            logging.error('Error trying to get stats API response.')

        # If API is blocked, then scrape about page and get number of users that way
        if (num_of_users is None):
            try:
                req = requests.get('https://' + the_domain + '/about')
                if (req.status_code == 200):
                    num_of_users_regex_output = MASTO_ABOUT_REGEX.search(req.text)
                    if (num_of_users_regex_output is not None):
                        num_of_users = num_of_users_regex_output[1]
                    else:
                        logging.error('Error trying to regex output of About page.')
            except:
                logging.error('Error trying to get About page html.')

    return num_of_users


def main():
    domain_list = ENV.callShellCmd(['psql','-t','-d','mastodon_production','-c',MASTO_DOMAIN_LIST_SQL])
    domain_list = domain_list.splitlines()

    domains_not_responding = []
    domains_responding_but_no_info = []
    domains_that_are_of_a_decent_and_respectable_size = {}
    too_big_domains = {}

    for the_domain in domain_list:
        try:
            the_domain = the_domain.strip()
            num_of_users = None
            req = None

            logging.info('Checking {0} for number of users...'.format(the_domain))

            try:
                logging.debug('Trying to check availability of https://{0}'.format(the_domain))
                req = requests.get('https://{0}'.format(the_domain), timeout=DOMAIN_CONNECTION_TIMEOUT)
            except:
                logging.error('Domain {0} not responding at all!'.format(the_domain))
                domains_not_responding.append(the_domain)

            if (req is not None):
                num_of_users = getNumOfUsersFromDomain(the_domain)

                # Block domains that are up but not Masto servers, and any Masto server over limit
                if ((num_of_users is not None)):
                    logging.info('Amount of users for {0}: {1}'.format(the_domain, num_of_users))
                    if (num_of_users > MASTO_USERS_LIMIT):
                        too_big_domains[the_domain] = num_of_users
                    else:
                        domains_that_are_of_a_decent_and_respectable_size[the_domain] = num_of_users
                elif (num_of_users is None):
                    domains_responding_but_no_info.append(the_domain)

                time.sleep(TIME_BETWEEN_REQUESTS)
        except Exception as e:
            logging.error('Exception while trying to examine {0}!\n{1}'.format(the_domain, e))

    # After looping through domains
    logging.info('Domains that are cool ({0}):'.format(len(domains_that_are_of_a_decent_and_respectable_size)))
    for the_domain, num_of_users in domains_that_are_of_a_decent_and_respectable_size.items():
        logging.info('{0}: {1}'.format(the_domain, num_of_users))

    logging.info('Domains that are too big to fail ({0}):'.format(len(too_big_domains)))
    for the_domain, num_of_users in too_big_domains.items():
        logging.info('{0}: {1}'.format(the_domain, num_of_users))

    logging.info('Domains that are up, but user information is not available ({0}):'.format(len(domains_responding_but_no_info)))
    for the_domain in domains_responding_but_no_info:
        logging.info(the_domain)

    logging.info('Domains that appeared to be down ({0}):'.format(len(domains_not_responding)))
    for the_domain in domains_not_responding:
        logging.info('{0} did not respond.'.format(the_domain))


if __name__ == "__main__":
    main()