pragma solidity ^0.4.19;

import './MintableToken.sol';


/**
 * Мой контракт, унаследован от контракта MintableToken
 */
contract MyTestToken is MintableToken {

    string public constant name = "Simple Coin Token";

    string public constant symbol = "SCT";

    uint32 public constant decimals = 18;

}

contract Crowdsale is Ownable {

    using SafeMath for uint;

    // укажем счет-экскроу, на который будет поступать эфир от инвесторов
    address multisig;

    // Переменная для хранения процента бонусов, в нашем случае 10%
    uint bonusPercent;

    MyTestToken public token = new MyTestToken();

    // Дата начала ICO
    uint start;

    // Период ICO
    uint period;

    // Период, через который держатели токенов, смогут получить бонусы
    uint periodBonuses;

    uint hardcap;

    // Коэфициент пересчета, в нашем случае будет 1 эфир = 10 токенам
    uint rate;

    // Посчитаем держателей наших токенов, в данной переменной, будет храниться
    // количество наших инвесторов

    // Переменная в которой будет храниться первая дата получения бонусов
    // Для каждого держателя токена она будет сдвигаться на 4 недели после получения бонучв
    uint public startPayPeriodBonuses;

    // Будем в мэппинг записывать наших держателей
    mapping (address => uint) public payDataBonuses;

    // добавим события для логирования выплаты бонусов
    event Paybonuses(address tokenHolder, uint256 value, uint datePay);

    function Crowdsale() {
        // Account 3 в метамаске
        multisig = 0x0D8d9Dd4a25d48F891DAD41Ca17C23c0b3e794AF;
        // Выпустим для бонуса 10 процентов от всех выпущеных токенов
        bonusPercent = 10;
        rate = 10 * (10 ** 18);
        // 04.02.2018 12:00 - начало ICO
        start = 1517745600;
        // Пусть наше ico длится 12 дней, ниже добавим модификатор, где будем
        // это проверять
        period = 12;
        periodBonuses = 4;

        // Инициализируем переменную датой, раньше которой бонусы не могут
        // быть уплачены
        startPayPeriodBonuses = start + period * 1 days + periodBonuses * 1 weeks;
        // Пусть для нашего ico необходима сумма в 100 эфиров, при достижении
        // этой суммы прекращаем продажу токенов
        hardcap = 100 * (10 ** 18);
    }

    modifier saleIsOn() {
        require(now > start && now < start + period * 1 days);
        _;
    }

    // В данном модификаторе будем проверять, что с момента окончания ico
    // прошло достаточное количества месяцев для выплаты бонусов
    // Проверямем, что дата выплаты наступила
    modifier periodBonusesIsOn() {
        require(now > startPayPeriodBonuses);
        _;
    }

    modifier isUnderHardCap() {
        require(multisig.balance <= hardcap);
        _;
    }

    function finishMinting() public onlyOwner {
        // После окончания эмиссии токенов, выпустим долю токенов для наших нужд
        // в нашем случае это 10% для выплаты бонусов
        uint issuedTokenSupply = token.totalSupply();
        uint restrictedTokens = issuedTokenSupply.mul(bonusPercent).div(100);
        token.mint(this, restrictedTokens);
        token.finishMinting();
    }

    function createTokens() isUnderHardCap saleIsOn payable {
        multisig.transfer(msg.value);
        // Переводим присланный эфир по курсу выше и по курсу делаем выпуск
        // токенов, например для присланных 10 эфиров будет выпущено 100 токенов
        uint tokens = rate.mul(msg.value).div(1 ether);
        token.mint(msg.sender, tokens);
        // Запишем адреса владельцев токена и установим ему первую дату выплаты
        payDataBonuses[msg.sender] = startPayPeriodBonuses;

    }

    // fallback функция срабатывает в момент получения эфира
    function() external payable {
        createTokens();
    }

    function getBonuses() periodBonusesIsOn {
        // Проверим баланс токенов, и от фактического остатка начислим 10% токенов
        // в виде бонусов
        require(token.balanceOf(msg.sender) > 0);
        uint value = token.balanceOf(msg.sender).mul(bonusPercent).div(100);
        token.transfer(msg.sender, value);
        payDataBonuses[msg.sender] = startPayPeriodBonuses + periodBonuses * 1 weeks;
        Paybonuses(msg.sender, value, startPayPeriodBonuses + periodBonuses * 1 weeks);
    }

    function changeMonthForBonus() public onlyOwner {
        startPayPeriodBonuses = startPayPeriodBonuses + periodBonuses * 1 weeks;
    }
}
