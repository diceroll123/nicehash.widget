command: "echo {}"

refreshFrequency: 10000 # ms

style: """
  top: 0px
  right: 0px
  color: #fff
  font-family: Helvetica Neue

  table
    border-collapse: collapsec
    table-layout: fixed
    -webkit-font-smoothing: antialiased
    -moz-osx-font-smoothing: grayscale

  td
    font-size: 30px
    font-weight: 200

  .wrapper
    padding: 5px 5px 5px 5px
    position: relative

  .label
    font-weight: normal
    font-size: 16 px

  #logo
    max-height 80px
    margin-top 10px
    margin-left 5px
    margin-bottom -10px

    background url(nicehash.widget/sprite.svg) no-repeat
    background-size 600px 600px
    background-position 0px -49px
    width 200px
    height 54px
    display block

  .pos
    color: #66ff66

  .neg
    color: #ff6666

  span
    -webkit-transition: all 0.5s ease;
    -moz-transition: all 0.5s ease;
    -o-transition: all 0.5s ease;
    transition: all 0.5s ease;
"""

render: ->
  """
  <div id="logo"></div>
  <table>
    <tr>
      <td>
        <div class='wrapper' id='wallet'>
          <span class='label'>Internal Wallet Balance</span> <br>
          <span id='internalbalance'>0.00000000</span>₿<br>
          $ <span id='internalusd'>0.00</span>
        </div>
      </td>
    </tr>
    <tr>
      <td>
        <div class='wrapper' id='unpaid'>
          <span class='label'>Unpaid Mining Balance</span> <br>
          <span id='miningbalance'>0.00000000</span>₿<br>
          $ <span id='miningusd'>0.00</span>
        </div>
      </td>
    </tr>
    <tr>
      <td>
        <div class='wrapper' id='projected'>
          <span class='label'>Projected Daily Income</span> <br>
          <span id='dailybalance'>0.00000000</span>₿<br>
          $ <span id='dailyusd'>0.00</span>
        </div>
      </td>
    </tr>
  </table>
"""

makeCommand: ->
  @command = "python3 ./nicehash.widget/nicehash.py" # edit the python file with your details

afterRender: (domEl) ->
  $(domEl).fadeTo(0, 0.3)
  $.getScript "nicehash.widget/lib/countUp.js"

  $(domEl).on 'click', '#logo', (e) =>
    @run "open https://www.nicehash.com/"

  @makeCommand()
  @refresh()

updateNumbers: (domEl, id, newValue, decimals) ->
  beginVal = parseFloat($(domEl).find('#' + id).html())
  newValue = parseFloat(newValue)
  endVal = parseFloat(newValue.toFixed(decimals))

  if endVal == beginVal
    return

  if beginVal > 0
    if endVal > beginVal
      $(domEl).find('#' + id).addClass('pos')
    else if beginVal > endVal
      $(domEl).find('#' + id).addClass('neg')

  bigNumber = decimals > 2

  numAnim = new CountUp(id, beginVal, endVal, decimals)
  if !numAnim.error
    numAnim.start ->
      $(domEl).find('#' + id).removeClass('neg pos')
  else
    console.error numAnim.error

update: (output, domEl) ->
  try
    data = JSON.parse(output)
  catch e
    # console.error(e)
    return

  # console.log(data)
  return unless data.wallet? or data.projected? or data.unpaid? or data.error? # needs SOMETHING...

  $domEl = $(domEl)
  if !data.error?
    if data.wallet.USD != '0.00'
      $domEl.find('#wallet').fadeIn()
      @updateNumbers(domEl, 'internalbalance', data.wallet.BTC, 8)
      @updateNumbers(domEl, 'internalusd', data.wallet.USD, 2)
    else
      $domEl.find('#wallet').fadeOut()

    if data.unpaid.USD != '0.00'
      $domEl.find('#unpaid').fadeIn()
      @updateNumbers(domEl, 'miningbalance', data.unpaid.BTC, 8)
      @updateNumbers(domEl, 'miningusd', data.unpaid.USD, 2)
    else
      $domEl.find('#unpaid').fadeOut()

    if data.projected.USD != '0.00'
      $domEl.find('#projected').fadeIn()
      @updateNumbers(domEl, 'dailybalance', data.projected.BTC, 8)
      @updateNumbers(domEl, 'dailyusd', data.projected.USD, 2)
    else
      $domEl.find('#projected').fadeOut()

    $domEl.fadeTo(1000, 1)
  else
    console.error data.error
    $domEl.fadeTo(1000, 0.3)
  @makeCommand()
