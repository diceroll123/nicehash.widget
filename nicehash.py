import config  # change your Nicehash info in there!
import json
import requests
import time


class Bitcoin:
    def __new__(self, num):
        try:
            amount = float(num)
        except:
            amount = 0.0
        return f'{amount:,.8f}'  # down to the hundred-millionths


class InternalBalance:
    balance_pending = 0
    balance_confirmed = 0

    @classmethod
    def from_data(cls, data):
        self = cls.__new__(cls)
        self.balance_pending = float(data.get('balance_pending', 0))
        self.balance_confirmed = float(data.get('balance_confirmed', 0))
        return self

    @property
    def total(self):
        return self.balance_pending + self.balance_confirmed


class MinerStatus:
    data = {}

    def _iterator(self):
        for attr in ['unpaid', 'projected']:
            value = getattr(self, attr, None)
            if value is not None:
                if self.coinbase is not None:
                    yield (attr, self.coinbase.convert(value))
                else:
                    yield (attr, value)

    def __iter__(self):
        return self._iterator()

    def __str__(self):
        return str(dict(self))

    @property
    def coinbase(self):
        return self._coinbase

    @coinbase.setter
    def coinbase(self, coinbase):
        self._coinbase = coinbase

    @classmethod
    def from_data(cls, data):
        self = cls.__new__(cls)
        self.data = data
        self._coinbase = None
        return self

    @property
    def unpaid(self):
        balance = 0
        if 'current' in self.data:
            balance = sum([float(alg['data'][1]) for alg in self.data['current'] if len(alg['data'])])
        return balance

    def get_unpaid(self):
        return self.unpaid

    @property
    def projected(self):  # daily, that is. by the last hour, as the url in Client only returns last hour.
        # This returns a rather unfair value if you haven't been mining for an hour.
        amount = 0
        if 'past' in self.data:
            amount = sum([(float(alg['data'][-1][2]) - float(alg['data'][0][2])) for alg in self.data['past'] if
                          len(alg['data'])]) * 24
        return max(0, amount)

    def get_projected(self):
        return self.projected


class Coinbase:
    def __init__(self):
        self._price = 0

    @property
    def price(self):
        if self._price is 0:
            r = requests.get('https://api.coinbase.com/v2/exchange-rates')
            self._price = 1 / float(r.json()['data']['rates']['BTC'])
        return self._price

    @price.setter
    def price(self, amount):
        self._price = amount

    def convert(self, btc):
        if btc is 0:
            return {'USD': '0.00', 'BTC': Bitcoin(0)}
        return {'USD': f'{self.price * btc:,.2f}', 'BTC': Bitcoin(btc)}


class Client:
    def __init__(self, *, api_key=None, api_id=None, miner_address=None):
        self._api_key = api_key
        self._api_id = api_id
        self._miner_address = miner_address
        if not all([api_key, api_id, miner_address]):
            raise Exception('All config.py keys are required.')
        self._coinbase = Coinbase()

    def get_balance(self):
        r = requests.get(f'https://api.nicehash.com/api?method=balance&id={self._api_id}&key={self._api_key}')
        result = r.json()['result']
        if 'error' in result:
            raise Exception(result['error'] + ', from get_balance')
        balance = InternalBalance.from_data(result)
        return self._coinbase.convert(balance.total)

    def get_miner_stats(self):
        r = requests.get(
            f'https://api.nicehash.com/api?method=stats.provider.ex&addr={self._miner_address}&from={int(time.time()) - 3900}')  # 65 min to get the last full hour
        if 'error' in r.json()['result']:
            raise Exception(r.json()['result']['error'] + ', from get_miner_stats')
        miner = MinerStatus.from_data(r.json()['result'])
        miner.coinbase = self._coinbase
        return dict(miner)

    def get_widget_data(self):
        # Ubersicht works by parsing the returned value of this script from a console command, so it prints JSON.
        try:
            result = nh.get_miner_stats()
            result['wallet'] = nh.get_balance()
            print(json.dumps(result))
        except Exception as e:
            print(json.dumps({'error': str(e)}))


nh = Client(**config.KEYS)
nh.get_widget_data()
