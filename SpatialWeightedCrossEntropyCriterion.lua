require 'nn'

local SpatialWeightedCrossEntropyCriterion, parent = torch.class('cudnn.SpatialWeightedCrossEntropyCriterion', 'nn.CriterionW')

--[[
    This criterion does the SpatialCrossEntropyCriterion across
    the feature dimension for a N-channel image of HxW in size.

    It only supports mini-batches (4D input, 3D target)

    It does a LogSoftMax on the input (over the channel dimension),
    so no LogSoftMax is needed in the network at the end

    input = batchSize x nClasses x H x W
    target = batchSize x H x W
]]--
function SpatialWeightedCrossEntropyCriterion:__init(weights)
    parent.__init(self)
    self.slsm = cudnn.SpatialLogSoftMax()
    self.nll = nn.SpatialWeightedClassNLLCriterion(weights)
    self.sizeAverage = true
end

function SpatialWeightedCrossEntropyCriterion:updateOutput(input, target, spWeights)
    assert(input:dim() == 4, 'mini-batch supported only')
    assert(target:dim() == 3, 'mini-batch supported only')
    assert(spWeights:dim() == 3, 'mini-batch supported only')
    assert(input:size(1) == target:size(1), 'input and target should be of same size')
    assert(input:size(3) == target:size(2), 'input and target should be of same size')
    assert(input:size(4) == target:size(3), 'input and target should be of same size')
    assert(input:size(1) == spWeights:size(1), 'input and target should be of same size')
    assert(input:size(3) == spWeights:size(2), 'input and target should be of same size')
    assert(input:size(4) == spWeights:size(3), 'input and target should be of same size')
    -- apply SpatialLogSoftMax to input
    self.slsm:updateOutput(input)

    -- Update submodule sizeAverage to make it consistent.
    self.nll.sizeAverage = self.sizeAverage

    -- fold the height and width dims into the mini-batch dim.
    self.nll:updateOutput(self.slsm.output, target, spWeights)
    self.output = self.nll.output
    return self.output
end

function SpatialWeightedCrossEntropyCriterion:updateGradInput(input, target, spWeights)
    assert(input:dim() == 4, 'mini-batch supported only')
    assert(target:dim() == 3, 'mini-batch supported only')
    assert(input:size(1) == target:size(1), 'input and target should be of same size')
    assert(input:size(3) == target:size(2), 'input and target should be of same size')
    assert(input:size(4) == target:size(3), 'input and target should be of same size')
    assert(input:size(1) == spWeights:size(1), 'input and target should be of same size')
    assert(input:size(3) == spWeights:size(2), 'input and target should be of same size')
    assert(input:size(4) == spWeights:size(3), 'input and target should be of same size')

    self.nll:updateGradInput(self.slsm.output, target, spWeights)

    -- unfold the height and width dims back
    self.slsm:updateGradInput(input, self.nll.gradInput)
    self.gradInput = self.slsm.gradInput
    return self.gradInput
end

function SpatialWeightedCrossEntropyCriterion:type(type)
    if type then
        self.nll:type(type)
        self.slsm:type(type)
    end
    parent.type(self, type)
    return self
end
