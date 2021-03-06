package fluxmonitorv2_test

import (
	"math/big"
	"testing"

	"github.com/smartcontractkit/chainlink/core/internal/cltest"
	"github.com/smartcontractkit/chainlink/core/internal/mocks"
	"github.com/smartcontractkit/chainlink/core/services/fluxmonitorv2"
	fmmocks "github.com/smartcontractkit/chainlink/core/services/fluxmonitorv2/mocks"
	"github.com/stretchr/testify/assert"
)

func TestFluxAggregatorContractSubmitter_Submit(t *testing.T) {
	var (
		fluxAggregator = new(mocks.FluxAggregator)
		orm            = new(fmmocks.ORM)
		keyStore       = new(fmmocks.KeyStoreInterface)
		gasLimit       = uint64(2100)
		submitter      = fluxmonitorv2.NewFluxAggregatorContractSubmitter(fluxAggregator, orm, keyStore, gasLimit, 0)

		toAddress   = cltest.NewAddress()
		fromAddress = cltest.NewAddress()
		roundID     = big.NewInt(1)
		submission  = big.NewInt(2)
	)

	payload, err := fluxmonitorv2.FluxAggregatorABI.Pack("submit", roundID, submission)
	assert.NoError(t, err)

	keyStore.On("GetRoundRobinAddress").Return(fromAddress, nil)
	fluxAggregator.On("Address").Return(toAddress)
	orm.On("CreateEthTransaction", fromAddress, toAddress, payload, gasLimit, uint64(0)).Return(nil)

	err = submitter.Submit(roundID, submission)
	assert.NoError(t, err)
}
